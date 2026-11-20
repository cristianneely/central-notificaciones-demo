class Notification
  # El despachador: toma los pendientes y los saca. Corre en segundo plano, cada
  # segundo, separado de la petición que pidió el envío (R13).
  module Despachador
    # Una vuelta: toma hasta 20 pendientes, lo crítico primero y después lo más antiguo.
    # Devuelve cuántos tomó.
    def self.vuelta(ahora: Time.current)
      # Reintentos por canal: mientras un canal espera su próximo intento, no se toma
      # ningún pendiente. Llegado el momento, se prueba con el de mayor prioridad.
      return 0 if EstadoCanal.alguno_en_espera?(ahora)

      tomados = 0
      Pendiente.en_orden.limit(Configuracion::PENDIENTES_POR_VUELTA).each do |pendiente|
        tomados += 1
        # Cada pendiente va en su propia transacción: lo que se anota y el borrado del
        # pendiente ocurren juntos, o no ocurre ninguno.
        resultado = ActiveRecord::Base.transaction do
          # Se confirma, ya dentro de la transacción, que el pendiente sigue en la fila.
          procesar(pendiente, ahora) if Pendiente.exists?(pendiente.id)
        end

        # El proveedor no respondió: el canal quedó en espera y la vuelta termina.
        break if resultado == :canal_en_espera
      rescue StandardError => error
        # Un error inesperado con un pendiente no detiene a los demás: se deshace lo de
        # ese pendiente, queda en la fila y se vuelve a intentar en la vuelta siguiente.
        Rails.logger.error("[central] error con el pendiente #{pendiente.id}: #{error.class}: #{error.message}")
      end

      tomados
    end

    # Los pasos por pendiente, en orden. El primero que corta, termina.
    def self.procesar(pendiente, ahora)
      # Un pendiente que vuelve tras una caída ya tiene su decisión anotada: no vuelve a
      # pasar por la política, el límite ni la decisión (pasos 2, 4 y 5) y reanuda en la
      # entrega, por el canal de su última decisión. Así cada solicitud tiene una sola
      # decisión por canal en su recorrido. La persona y su dato de contacto (pasos 1 y 3) sí se vuelven a buscar,
      # porque la dirección no se guarda en el pendiente.
      decision = Auditoria.recorrido(pendiente.solicitud_id, pendiente.usuario_id)
                          .where(evento: "decision_enviar").last

      # 1. Persona: tiene que existir y ser de esa empresa. Si no, no hay a quién enviar.
      usuario = Usuario.find_by(id: pendiente.usuario_id, empresa_id: pendiente.empresa_id)
      return terminar(pendiente, "no_enviada", motivo: "sin_contacto") unless usuario

      nombre_canal = decision&.canal
      unless decision
        # 2. Política: por qué canal sale. Parte por el primero de los efectivos. Si la
        #    empresa los apagó todos, no se envía.
        nombre_canal = Politicas.canales_efectivos(empresa_id: pendiente.empresa_id,
                                                   criticidad: pendiente.criticidad).first
        return terminar(pendiente, "no_enviada", motivo: "politica_cliente") unless nombre_canal
      end

      # 3. Contacto: cada canal dice qué dato de la persona necesita (el email, su
      #    correo) y la central lo busca. Si la persona no lo tiene, no hay a dónde enviar.
      canal = Canales.buscar(nombre_canal)
      contacto = Contactos.buscar(usuario, canal.contacto)
      return terminar(pendiente, "no_enviada", canal: nombre_canal, motivo: "sin_contacto") unless contacto

      unless decision
        # 4. Límite de frecuencia (R3), solo para lo no crítico: lo que excede se
        #    descarta. No se envía, pero queda anotado con su motivo.
        if pendiente.criticidad != "critica"
          llevaba = no_criticas_recientes(pendiente.usuario_id, nombre_canal, ahora)
          limite = Configuracion::LIMITE_FRECUENCIA
          if llevaba >= limite
            return terminar(pendiente, "descartada", canal: nombre_canal, motivo: "limite_frecuencia",
                                                   detalle: { llevaba: llevaba, limite: limite })
          end
        end

        # 5. La decisión de enviar queda anotada antes de hablar con el proveedor.
        Auditoria.anotar(pendiente, "decision_enviar", canal: nombre_canal)
      end

      # 6. El canal adapta el contenido a su formato y lo entrega a su proveedor.
      definicion = Notification.catalogo.buscar(pendiente.notificacion)
      contenido = Contenido.rellenar(definicion, pendiente.datos)

      loop do
        resultado = canal.entregar(canal.adaptar(contenido), pendiente: pendiente, para: contacto,
                                                             version: definicion.version)

        # Si el proveedor no respondió, el pendiente se queda en la fila y reanuda después
        # por este mismo canal.
        return :canal_en_espera if resultado.sin_respuesta?

        # 7. Respaldo de lo crítico (R6): si el canal rechazó el envío en forma definitiva,
        #    lo crítico se intenta por el canal siguiente de la política. Lo demás termina
        #    aquí. Un rebote que el proveedor informa después no pasa por este punto.
        respaldo = canal_siguiente(pendiente, canal.nombre) if resultado.rechazado? && pendiente.criticidad == "critica"
        break unless respaldo

        canal = Canales.buscar(respaldo)
        contacto = Contactos.buscar(usuario, canal.contacto)
        return terminar(pendiente, "no_enviada", canal: respaldo, motivo: "sin_contacto") unless contacto

        Auditoria.anotar(pendiente, "decision_enviar", canal: respaldo)
      end

      # Enviado o rechazado sin más canales: el pendiente ya terminó y se borra.
      pendiente.destroy!
      :terminado
    end

    # El canal efectivo que viene después de `actual` para ese pendiente, o nil si no hay.
    def self.canal_siguiente(pendiente, actual)
      efectivos = Politicas.canales_efectivos(empresa_id: pendiente.empresa_id, criticidad: pendiente.criticidad)
      posicion = efectivos.index(actual)
      posicion && efectivos[posicion + 1]
    end

    # Cuántas notificaciones no críticas se decidió enviar a esa persona por ese canal
    # dentro de la ventana. Se cuenta sobre la auditoría, no con un contador aparte:
    # cuenta la decisión de enviar, no la entrega.
    def self.no_criticas_recientes(usuario_id, canal, ahora)
      desde = ahora - Configuracion::VENTANA_LIMITE
      Auditoria.where(usuario_id: usuario_id, canal: canal, evento: "decision_enviar")
               .where.not(criticidad: "critica")
               .where("creado_en > ?", desde)
               .count
    end

    # Cierra un pendiente que no se va a enviar: anota por qué y lo saca de la fila.
    def self.terminar(pendiente, evento, canal: nil, motivo:, detalle: {})
      Auditoria.anotar(pendiente, evento, canal: canal, motivo: motivo, detalle: detalle)
      pendiente.destroy!
      :terminado
    end

    private_class_method :procesar, :terminar, :no_criticas_recientes, :canal_siguiente
  end
end
