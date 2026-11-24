class Notification
  # El contenido de una notificación: una lista ordenada de piezas de un vocabulario
  # cerrado. Dice qué es cada parte (un título, un botón), no cómo se ve: eso lo decide
  # cada canal al dibujarla.
  module Contenido
    VOCABULARIO = %i[titulo resumen parrafo destacado lista imagen boton personas].freeze
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

      # Cada pieza recibe cualquier cosa: si no viene en su forma (un argumento de más, una
      # clave que no es suya), se anota como mal escrita y el catálogo dice cómo se escribe,
      # en vez de que la clase reviente al cargar con un error de Ruby.
      DE_TEXTO.each do |tipo|
        define_method(tipo) do |*argumentos, **opciones|
          bien = argumentos.size <= 1 && opciones.empty?
          @piezas << (bien ? { tipo: tipo, texto: argumentos.first } : { tipo: tipo, mal_escrita: true })
        end
      end

      def lista(*items, **opciones)
        @piezas << (opciones.empty? ? { tipo: :lista, items: items.flatten } : { tipo: :lista, mal_escrita: true })
      end

      def imagen(*argumentos, **opciones)
        bien = argumentos.size <= 1 && (opciones.keys - [:alt]).empty?
        @piezas << (bien ? { tipo: :imagen, url: argumentos.first, alt: opciones[:alt] } : { tipo: :imagen, mal_escrita: true })
      end

      # personas "{dato}": el texto es solo el marcador del dato que trae la lista.
      def personas(*argumentos, **opciones)
        bien = argumentos.size == 1 && opciones.empty? && argumentos.first.is_a?(::String) &&
               argumentos.first.match?(/\A\{\w+\}\z/)
        @piezas << (bien ? { tipo: :personas, dato: argumentos.first } : { tipo: :personas, mal_escrita: true })
      end

      def boton(*argumentos, **opciones)
        bien = argumentos.size <= 1 && (opciones.keys - [:link]).empty?
        @piezas << (bien ? { tipo: :boton, texto: argumentos.first, link: opciones[:link] } : { tipo: :boton, mal_escrita: true })
      end

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
    # se reemplaza por el valor de ese dato, como texto. Un dato que es una lista de
    # personas se escribe con sus nombres ("Ana, Bruno y Carla"): quien pide el envío no
    # los repite en otro dato. La pieza personas no es texto: recibe la lista del dato tal
    # cual, con el nombre y la foto de cada persona.
    def self.rellenar(definicion, datos)
      datos = datos.to_h.transform_keys(&:to_sym)
      rellenar = ->(valor) do
        case valor
        when String then valor.gsub(ValidadorDefinicion::MARCADOR) { como_texto(datos[$1.to_sym]) }
        when Array then valor.map(&rellenar)
        else valor
        end
      end

      piezas = definicion.contenido.map do |pieza|
        next pieza.transform_values(&rellenar) unless pieza[:tipo] == :personas

        dato = pieza[:dato][ValidadorDefinicion::MARCADOR, 1].to_sym
        { tipo: :personas, gente: personas_de(datos[dato]) }
      end

      Relleno.new(notificacion: definicion.nombre, piezas: piezas)
    end

    # El valor de un dato dentro de un texto. Una lista de personas, con sus nombres.
    def self.como_texto(valor)
      return valor.to_s unless valor.is_a?(Array)

      personas_de(valor).map { |persona| persona[:nombre] }
                        .to_sentence(words_connector: ", ", two_words_connector: " y ", last_word_connector: " y ")
    end

    # [{ "nombre" => …, "foto" => … }] → [{ nombre:, foto: }]. Lo que no sea una lista de
    # personas queda como lista vacía: send() ya lo rechazó antes de llegar aquí.
    def self.personas_de(valor)
      return [] unless valor.is_a?(Array)

      valor.filter_map do |persona|
        next unless persona.respond_to?(:to_h)

        persona = persona.to_h.transform_keys(&:to_s)
        { nombre: persona["nombre"].to_s, foto: persona["foto"].to_s }
      end
    end
  end
end
