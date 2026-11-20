class Notification
  # El contenido de una notificación: una lista ordenada de piezas de un vocabulario
  # cerrado. Dice qué es cada parte (un título, un botón), no cómo se ve: eso lo decide
  # cada canal al dibujarla.
  module Contenido
    VOCABULARIO = %i[titulo resumen parrafo destacado lista imagen boton].freeze
    # Las piezas que son solo un texto.
    DE_TEXTO = %i[titulo resumen parrafo destacado].freeze

    # Lo que recibe un canal: las piezas de una notificación con los datos ya puestos.
    Relleno = Data.define(:notificacion, :piezas) do
      def titulo = de(:titulo).first&.fetch(:texto)
      def resumen = de(:resumen).first&.fetch(:texto)

      # Las piezas de un tipo, en el orden en que se declararon.
      def de(tipo)
        piezas.select { |pieza| pieza[:tipo] == tipo }
      end
    end

    # Anota las piezas que se escriben dentro de `contenido do ... end`.
    class Constructor < BasicObject
      attr_reader :piezas

      def initialize
        @piezas = []
      end

      DE_TEXTO.each do |tipo|
        define_method(tipo) { |texto = nil| @piezas << { tipo: tipo, texto: texto } }
      end

      def lista(*items) = @piezas << { tipo: :lista, items: items.flatten }
      def imagen(url = nil, alt: nil) = @piezas << { tipo: :imagen, url: url, alt: alt }
      def boton(texto = nil, link: nil) = @piezas << { tipo: :boton, texto: texto, link: link }

      # Una pieza que no es del vocabulario no rompe la carga: se anota, y el catálogo
      # la informa junto con los demás errores.
      def method_missing(nombre, *, **)
        @piezas << { tipo: nombre }
      end

      def respond_to_missing?(*) = true
    end

    # Evalúa el bloque de una definición y devuelve sus piezas, en orden.
    def self.declarar(&bloque)
      constructor = Constructor.new
      constructor.instance_eval(&bloque)
      constructor.piezas
    end

    # Rellena las piezas de una definición con los datos de un envío: cada {marcador}
    # se reemplaza por el valor de ese dato, como texto.
    def self.rellenar(definicion, datos)
      datos = datos.to_h.transform_keys(&:to_sym)
      rellenar = ->(valor) do
        case valor
        when String then valor.gsub(ValidadorDefinicion::MARCADOR) { datos[$1.to_sym].to_s }
        when Array then valor.map(&rellenar)
        else valor
        end
      end

      Relleno.new(notificacion: definicion.nombre,
                  piezas: definicion.contenido.map { |pieza| pieza.transform_values(&rellenar) })
    end
  end
end
