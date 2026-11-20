class Notification
  module Canales
    # El canal email. Es el único lugar del código que habla con el proveedor de
    # correo (R1): nadie más puede enviar un correo sin pasar por la central.
    class Email < Base
      def nombre
        "email"
      end

      # El dato de la persona que este canal necesita para entregar.
      def contacto
        :correo
      end

      # Piezas → correo: el título es el asunto, los párrafos son el cuerpo y el botón,
      # si lo hay, es un botón.
      def adaptar(contenido)
        boton = contenido.de(:boton).first
        {
          asunto: contenido.titulo,
          cuerpo: contenido.de(:parrafo).map { |pieza| pieza[:texto] }.join("\n"),
          accion_texto: boton&.fetch(:texto),
          accion_link: boton&.fetch(:link)
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
