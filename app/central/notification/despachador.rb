module Notification
  # El despachador: toma los pendientes y los saca. Corre en segundo plano, cada
  # segundo, separado de la petición que pidió el envío (R13).
  module Despachador
    # Una vuelta: toma hasta 20 pendientes, lo crítico primero y después lo más antiguo.
    # Devuelve cuántos tomó.
    def self.vuelta(ahora: Time.current)
      tomados = Pendiente.en_orden.limit(Configuracion::PENDIENTES_POR_VUELTA).to_a

      tomados.each do |pendiente|
        # Cada pendiente va en su propia transacción: lo que se anota y el borrado del
        # pendiente ocurren juntos, o no ocurre ninguno.
        ActiveRecord::Base.transaction { procesar(pendiente, ahora) }
      rescue StandardError => error
        # Un error inesperado con un pendiente no detiene a los demás: se deshace lo de
        # ese pendiente, queda en la fila y se vuelve a intentar en la vuelta siguiente.
        Rails.logger.error("[central] error con el pendiente #{pendiente.id}: #{error.class}: #{error.message}")
      end

      tomados.size
    end

    # Los pasos por pendiente, en orden. El primero que corta, termina.
    def self.procesar(pendiente, ahora)
      # 1. Contacto: la central busca el correo de la persona. Si la persona no existe,
      #    no es de esa empresa o no tiene correo, no hay a dónde enviar.
      usuario = Usuario.find_by(id: pendiente.usuario_id, empresa_id: pendiente.empresa_id)
      contacto = usuario&.email.to_s.strip
      return terminar(pendiente, "no_enviada", motivo: "sin_contacto") if contacto.empty?

      # 2. Política: por qué canal sale. Se usa un solo canal, el primero de los
      #    efectivos. Si la empresa los apagó todos, no se envía.
      nombre_canal = Politicas.canales_efectivos(empresa_id: pendiente.empresa_id,
                                                 importancia: pendiente.importancia).first
      return terminar(pendiente, "no_enviada", motivo: "politica_cliente") unless nombre_canal

      # 4. La decisión de enviar queda anotada antes de hablar con el proveedor.
      Auditoria.anotar(pendiente, "decision_enviar", canal: nombre_canal)

      # 5. El canal adapta el contenido a su formato y lo entrega a su proveedor.
      canal = Canales.buscar(nombre_canal)
      definicion = Notification.catalogo.buscar(pendiente.notificacion)
      mensaje = canal.adaptar(Contenido.rellenar(definicion.contenido, pendiente.datos))
      canal.entregar(mensaje, pendiente: pendiente, para: contacto)

      pendiente.destroy!
    end

    # Cierra un pendiente que no se va a enviar: anota por qué y lo saca de la fila.
    def self.terminar(pendiente, evento, canal: nil, motivo:, detalle: {})
      Auditoria.anotar(pendiente, evento, canal: canal, motivo: motivo, detalle: detalle)
      pendiente.destroy!
    end

    private_class_method :procesar, :terminar
  end
end
