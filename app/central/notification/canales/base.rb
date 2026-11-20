class Notification
  module Canales
    # Lo común a todos los canales. Un canal nuevo declara cuatro cosas, y el despachador
    # solo conoce esas:
    #
    #   nombre                 — cómo se llama ("email").
    #   contacto               — qué dato de la persona necesita (:correo).
    #   adaptar(contenido)     — dibuja cada pieza del contenido (título, resumen,
    #                            párrafo, destacado, lista, imagen, botón) con el formato
    #                            del canal, y devuelve el mensaje para su proveedor.
    #   entregar_al_proveedor  — se lo pasa a su proveedor y devuelve qué respondió.
    #
    # Anotar el resultado en la auditoría es igual para todos y está aquí (`entregar`).
    class Base
      def nombre
        raise NotImplementedError
      end

      def contacto
        raise NotImplementedError
      end

      def adaptar(contenido)
        raise NotImplementedError
      end

      # Habla con el proveedor del canal y devuelve un Resultado.
      def entregar_al_proveedor(mensaje, pendiente:, para:)
        raise NotImplementedError
      end

      # Entrega el mensaje y deja anotado el resultado en la auditoría. `version` es la
      # del contenido con que se armó el mensaje.
      def entregar(mensaje, pendiente:, para:, version:)
        resultado = entregar_al_proveedor(mensaje, pendiente: pendiente, para: para)

        if resultado.aceptado?
          EstadoCanal.reiniciar(nombre)
          # Queda la receta y el destino, no el correo completo: a qué dirección salió y
          # con qué versión del contenido. Si la persona cambia de correo después, el
          # historial sigue diciendo a dónde se envió.
          Auditoria.anotar(pendiente, "enviada", canal: nombre,
                                                 detalle: { id_proveedor: resultado.id_proveedor,
                                                            para: para, version: version })
        elsif resultado.rechazado?
          # El proveedor rechazó este mensaje puntual: reintentar no sirve. Pero respondió,
          # así que el canal está sano.
          EstadoCanal.reiniciar(nombre)
          Auditoria.anotar(pendiente, "fallo_definitivo", canal: nombre,
                                                          motivo: "rechazado_por_proveedor",
                                                          detalle: { mensaje: resultado.mensaje })
        else
          # El proveedor no respondió: no es culpa de este mensaje. El canal entra en
          # espera y el pendiente se queda en la fila; nada se pierde (R14).
          estado = EstadoCanal.registrar_falla(nombre, Time.current)
          Auditoria.anotar(pendiente, "intento_fallido", canal: nombre,
                                                         motivo: "proveedor_no_disponible",
                                                         detalle: { falla_consecutiva: estado.fallas_consecutivas })
        end

        resultado
      end
    end
  end
end
