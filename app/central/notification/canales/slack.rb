class Notification
  module Canales
    # Slack (simulado): un mensaje con bloques. El título es el encabezado; el resumen,
    # el texto del aviso; párrafos, destacado y lista van con el formato de Slack; la
    # imagen y el botón, como bloques propios. Sabe dibujar todas las piezas.
    class Slack < Base
      def nombre = "slack"

      # El usuario de Slack de la persona. Las personas de la demo no lo tienen.
      def contacto = :slack

      def adaptar(contenido)
        { text: contenido.resumen, blocks: contenido.piezas.filter_map { |pieza| bloque(pieza) } }
      end

      def entregar_al_proveedor(mensaje, pendiente:, para:)
        Proveedores::MensajeriaSimulada.entregar(canal: nombre, mensaje: mensaje, para: para)
      end

      private

      def bloque(pieza)
        case pieza[:tipo]
        when :titulo then { type: "header", text: { type: "plain_text", text: pieza[:texto] } }
        when :parrafo then seccion(escapar(pieza[:texto]))
        when :destacado then seccion("*#{escapar(pieza[:texto])}*")
        when :lista then seccion(pieza[:items].map { |item| "• #{escapar(item)}" }.join("\n"))
        when :imagen then { type: "image", image_url: pieza[:url], alt_text: pieza[:alt] }
        when :boton
          { type: "actions",
            elements: [{ type: "button", text: { type: "plain_text", text: pieza[:texto] }, url: pieza[:link] }] }
        end
        # el resumen ya va como texto del aviso
      end

      def seccion(texto) = { type: "section", text: { type: "mrkdwn", text: texto } }

      # En el formato de Slack, "<" y ">" arman links: un dato no puede abrir uno.
      def escapar(texto)
        texto.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
      end
    end
  end
end
