module Demo
  # Una definición de ejemplo mal escrita, para el botón "Probar una definición inválida"
  # del catálogo. Le falta la criticidad, le falta unica_por, usa en el contenido un dato
  # que no declaró y trae una declaración que no existe (`canales`).
  module DefinicionInvalida
    NOMBRE = "aviso_mal_escrito"

    # El texto que se muestra en pantalla, tal como lo escribiría un equipo.
    CODIGO = <<~RUBY
      class AvisoMalEscrito < Notification
        datos     :curso
        contenido titulo: "Novedades de {curso}",
                  cuerpo: "Hola {dato_inexistente}."
        canales   [:email]
      end
    RUBY

    # Los errores que daría el catálogo. Solo valida: no la registra.
    def self.errores
      # La misma clase que muestra CODIGO, sin nombre para no dejarla en el programa.
      clase = Class.new(Notification) do
        datos     :curso
        contenido titulo: "Novedades de {curso}",
                  cuerpo: "Hola {dato_inexistente}."
        canales   [:email]
      end

      Notification::ValidadorDefinicion.errores(NOMBRE, clase.declarado)
    end
  end
end
