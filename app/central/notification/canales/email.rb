class Notification
  module Canales
    # El canal email. Es el único lugar del código que habla con el proveedor de
    # correo (R1): nadie más puede enviar un correo sin pasar por la central.
    class Email < Base
      def nombre
        "email"
      end

      # Contenido neutro → correo: el título es el asunto, el cuerpo es el cuerpo y la
      # acción, si la hay, es un botón.
      def adaptar(contenido)
        {
          asunto: contenido[:titulo],
          cuerpo: contenido[:cuerpo],
          accion_texto: contenido.dig(:accion, :texto),
          accion_link: contenido.dig(:accion, :link)
        }
      end

      # El proveedor tiene una sola operación: entregar. Hoy es el simulado; un
      # adaptador de un proveedor real se cambiaría en esta línea, sin tocar el resto.
      def entregar_al_proveedor(mensaje, pendiente:, para:)
        Proveedores::Simulado.entregar(
          mensaje.merge(para: para, solicitud_id: pendiente.solicitud_id, usuario_id: pendiente.usuario_id)
        )
      end
    end
  end
end
