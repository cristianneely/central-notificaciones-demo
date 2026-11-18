module Demo
  # Una definición de ejemplo mal escrita, para el botón "Probar una definición inválida"
  # del catálogo. Le falta la criticidad, le falta unica_por, usa en el contenido un dato
  # que no declaró y trae una clave que no existe (`canales`).
  module DefinicionInvalida
    NOMBRE = "aviso_mal_escrito"

    EJEMPLO = {
      datos: [:curso],
      contenido: { titulo: "Novedades de {curso}", cuerpo: "Hola {dato_inexistente}." },
      canales: [:email]
    }.freeze

    # El texto que se muestra en pantalla, tal como lo escribiría un equipo.
    CODIGO = <<~RUBY
      Notification.define "aviso_mal_escrito",
        datos: [:curso],
        contenido: {
          titulo: "Novedades de {curso}",
          cuerpo: "Hola {dato_inexistente}."
        },
        canales: [:email]
    RUBY

    # Los errores que daría el catálogo. Solo valida: no la registra.
    def self.errores
      Notification::ValidadorDefinicion.errores(NOMBRE, EJEMPLO)
    end
  end
end
