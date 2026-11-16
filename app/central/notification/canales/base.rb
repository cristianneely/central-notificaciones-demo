module Notification
  module Canales
    # Lo común a todos los canales. Todo canal tiene dos operaciones, y el despachador
    # solo conoce esas dos:
    #
    #   adaptar(contenido)  — convierte el contenido neutro (título, cuerpo, acción) en
    #                         un mensaje con el formato del canal.
    #   entregar(mensaje)   — se lo pasa a su proveedor y anota qué pasó.
    #
    # Un canal nuevo escribe `nombre`, `adaptar` y `entregar_al_proveedor`. Anotar el
    # resultado en la auditoría es igual para todos y está aquí.
    class Base
      def nombre
        raise NotImplementedError
      end

      def adaptar(contenido)
        raise NotImplementedError
      end

      # Habla con el proveedor del canal y devuelve un Resultado.
      def entregar_al_proveedor(mensaje, pendiente:, para:)
        raise NotImplementedError
      end

      # Entrega el mensaje y deja anotado el resultado en la auditoría.
      def entregar(mensaje, pendiente:, para:)
        resultado = entregar_al_proveedor(mensaje, pendiente: pendiente, para: para)

        if resultado.aceptado?
          EstadoCanal.reiniciar(nombre)
          Auditoria.anotar(pendiente, "enviada", canal: nombre,
                                                 detalle: { id_proveedor: resultado.id_proveedor })
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
