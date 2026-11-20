module Demo
  # Una definición de ejemplo mal escrita, para el botón "Probar una definición inválida"
  # del catálogo. Le falta la criticidad, le falta unica_por, usa una pieza que no es del
  # vocabulario (`video`), usa en el contenido un dato que no declaró y trae una
  # declaración que no existe (`canales`).
  module DefinicionInvalida
    NOMBRE = "aviso_mal_escrito"

    # El texto que se muestra en pantalla, tal como lo escribiría un equipo.
    CODIGO = <<~RUBY
      class AvisoMalEscrito < Notification
        datos   :curso
        canales [:email]

        contenido do
          titulo  "Novedades de {curso}"
          resumen "Hola {dato_inexistente}."
          video   "https://ejemplo.test/novedades.mp4"
        end
      end
    RUBY

    # Los errores que daría el catálogo. Solo valida: no la registra.
    def self.errores
      # La misma clase que muestra CODIGO, sin nombre para no dejarla en el programa.
      clase = Class.new(Notification) do
        datos   :curso
        canales [:email]

        contenido do
          titulo  "Novedades de {curso}"
          resumen "Hola {dato_inexistente}."
          video   "https://ejemplo.test/novedades.mp4"
        end
      end

      Notification::ValidadorDefinicion.errores(NOMBRE, clase.declarado)
    end
  end
end
