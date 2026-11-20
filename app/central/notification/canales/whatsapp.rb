class Notification
  module Canales
    # WhatsApp (simulado): texto con *negrita*, la imagen adjunta y el botón como botón
    # de una plantilla. Meta exige una plantilla aprobada por notificación; esa relación
    # vive aquí y la definición no cambia. Si una notificación no tiene plantilla, el
    # botón pasa a link dentro del texto.
    class Whatsapp < Base
      # Las notificaciones con plantilla aprobada (simuladas).
      PLANTILLAS = %w[certificado_emitido].freeze

      DEGRADA = {
        resumen: "Resumen: se omite",
        lista: "Lista: pasa a líneas con guion"
      }.freeze
      SIN_PLANTILLA = "Botón: pasa a link (sin plantilla aprobada)".freeze

      def nombre = "whatsapp"
      def contacto = :telefono

      def adaptar(contenido)
        plantilla = plantilla(contenido)
        boton = contenido.de(:boton).first
        imagen = contenido.de(:imagen).first
        lineas = contenido.piezas.filter_map { |pieza| linea(pieza) }
        lineas << "#{boton[:texto]}: #{boton[:link]}" if boton && !plantilla

        {
          plantilla: plantilla,
          texto: lineas.join("\n\n"),
          imagen: imagen&.slice(:url, :alt),
          boton: plantilla && boton&.slice(:texto, :link)
        }
      end

      def notas(contenido)
        notas = super
        notas << SIN_PLANTILLA if contenido.de(:boton).any? && !plantilla(contenido)
        notas
      end

      def entregar_al_proveedor(mensaje, pendiente:, para:)
        Proveedores::MensajeriaSimulada.entregar(canal: nombre, mensaje: mensaje, para: para)
      end

      private

      def plantilla(contenido)
        contenido.notificacion if PLANTILLAS.include?(contenido.notificacion)
      end

      def linea(pieza)
        case pieza[:tipo]
        when :titulo, :destacado then "*#{pieza[:texto]}*"
        when :parrafo then pieza[:texto]
        when :lista then pieza[:items].map { |item| "- #{item}" }.join("\n")
        end
        # la imagen va adjunta y el botón, en la plantilla
      end
    end
  end
end
