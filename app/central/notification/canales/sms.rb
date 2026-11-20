require "digest"

class Notification
  module Canales
    # SMS (simulado): el resumen y, si hay botón, un link corto, en 160 caracteres como
    # máximo. Es la razón de que el resumen sea obligatorio: aquí es todo el mensaje.
    class Sms < Base
      MAXIMO = 160
      # El acortador de links (simulado). Un mismo link da siempre el mismo link corto.
      ACORTADOR = "https://nj.test/".freeze

      DEGRADA = {
        titulo: "Título: se omite",
        parrafo: "Párrafo: se omite",
        destacado: "Destacado: se omite",
        lista: "Lista: se omite",
        imagen: "Imagen: se omite",
        boton: "Botón: pasa a link corto"
      }.freeze

      def nombre = "sms"
      def contacto = :telefono

      # Si no cabe, se recorta el resumen y termina en "…"; el link nunca se corta.
      def adaptar(contenido)
        boton = contenido.de(:boton).first
        link = boton && " #{ACORTADOR}#{Digest::SHA256.hexdigest(boton[:link])[0, 6]}"
        cabe = MAXIMO - link.to_s.length
        resumen = contenido.resumen
        resumen = "#{resumen[0, cabe - 1]}…" if resumen.length > cabe

        { texto: "#{resumen}#{link}" }
      end

      def entregar_al_proveedor(mensaje, pendiente:, para:)
        Proveedores::MensajeriaSimulada.entregar(canal: nombre, mensaje: mensaje, para: para)
      end
    end
  end
end
