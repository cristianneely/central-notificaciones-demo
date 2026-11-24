class Notification
  module Canales
    # Notificación push en el teléfono (simulada). Tiene espacio para un título y una o dos
    # líneas: el título va como título, el resumen como texto y la imagen se ve al
    # expandirla. No tiene botones propios: tocar la notificación abre el link del botón.
    class Push < Base
      DEGRADA = {
        parrafo: "Párrafo: se omite",
        destacado: "Destacado: se omite",
        lista: "Lista: se omite",
        boton: "Botón: tocar la notificación abre el link",
        personas: "Personas: solo la foto de la primera"
      }.freeze
      # Con una pieza imagen, se muestra esa: las personas no aparecen.
      PERSONAS_CON_IMAGEN = "Personas: se omite".freeze

      def nombre = "push"

      # El dispositivo registrado de la persona. Las personas de la demo no lo tienen.
      def contacto = :dispositivo

      def adaptar(contenido)
        {
          titulo: contenido.titulo,
          cuerpo: contenido.resumen,
          imagen: contenido.de(:imagen).first&.fetch(:url) || primera_foto(contenido),
          link: contenido.de(:boton).first&.fetch(:link)
        }
      end

      def notas(contenido)
        return super unless contenido.de(:imagen).any?

        super.map { |nota| nota == DEGRADA[:personas] ? PERSONAS_CON_IMAGEN : nota }
      end

      # Sin pieza imagen, la foto de la primera persona.
      def primera_foto(contenido)
        contenido.de(:personas).flat_map { |pieza| pieza[:gente] }.first&.fetch(:foto)
      end

      def entregar_al_proveedor(mensaje, pendiente:, para:)
        Proveedores::MensajeriaSimulada.entregar(canal: nombre, mensaje: mensaje, para: para)
      end
    end
  end
end
