class Notification
  # Las reglas de la API 1.1. Revisa una definición completa y devuelve todos sus errores
  # juntos (no se detiene en el primero), en el orden de la tabla de validaciones.
  module ValidadorDefinicion
    CLAVES = %i[criticidad datos unica_por contenido].freeze
    FORMATO_NOMBRE = /\A[a-z][a-z0-9_]*\z/
    MARCADOR = /\{(\w+)\}/
    # Cómo se escribe cada pieza, para el error de una pieza mal escrita.
    FORMAS = {
      titulo: 'titulo "texto"', resumen: 'resumen "texto"', parrafo: 'parrafo "texto"',
      destacado: 'destacado "texto"', lista: 'lista "uno", "dos"',
      imagen: 'imagen "url", alt: "texto"', boton: 'boton "texto", link: "url"',
      personas: 'personas "{dato}"'
    }.freeze

    # Devuelve la lista de mensajes de error; vacía si la definición es válida.
    def self.errores(nombre, opciones, nombres_existentes: [])
      errores = []
      datos = opciones[:datos]
      unica_por = opciones[:unica_por]
      piezas = opciones[:contenido].is_a?(Array) ? opciones[:contenido] : []

      # El nombre sale del nombre de la clase: minúsculas_con_guion_bajo y único en el
      # catálogo.
      if !nombre.is_a?(String) || !nombre.match?(FORMATO_NOMBRE)
        errores << "nombre inválido"
      elsif nombres_existentes.include?(nombre)
        errores << "ya existe una definición con ese nombre"
      end

      # La criticidad es obligatoria y solo puede ser una de las tres (R4).
      unless Configuracion::PRIORIDADES.key?(opciones[:criticidad])
        errores << "criticidad debe ser :critica, :informativa u :opcional"
      end

      # Los datos que la notificación necesita: una lista de nombres, sin repetir.
      datos_validos = datos.is_a?(Array) && datos.all?(Symbol) && datos.uniq == datos
      errores << "datos debe ser una lista de nombres sin repetir" unless datos_validos
      declarados = datos_validos ? datos : []

      # unica_por dice qué hace única a una notificación (R2). Sin eso no se puede
      # detectar un duplicado, así que es obligatorio.
      if !unica_por.is_a?(Array) || unica_por.empty?
        errores << "unica_por es obligatorio"
      else
        (unica_por - declarados).each do |dato|
          errores << "unica_por usa un dato no declarado: #{dato}"
        end
      end

      # El contenido es una lista de piezas del vocabulario (título, resumen, párrafo,
      # destacado, lista, imagen, botón y personas), sin formato de ningún canal.
      if opciones[:contenido].is_a?(Hash) && opciones[:contenido].any?
        errores << "contenido se declara con un bloque de piezas"
      else
        errores.concat(errores_de_piezas(piezas))
      end

      # Todo {marcador} del contenido tiene que ser un dato declarado.
      (marcadores(piezas) - declarados).each do |dato|
        errores << "el contenido usa un dato no declarado: #{dato}"
      end

      # Cualquier otra clave se rechaza. Por ejemplo `canales:`: la definición no elige
      # canales, eso lo deciden las políticas (R7).
      sobrantes = opciones.keys - CLAVES
      sobrantes.each { |clave| errores << "clave no permitida: #{clave}" }

      errores
    end

    def self.texto?(valor)
      valor.is_a?(String) && !valor.strip.empty?
    end

    # Título y resumen son obligatorios y van una sola vez: el resumen es lo que sale
    # donde el canal tiene una sola línea. Cada pieza trae lo que su tipo necesita.
    def self.errores_de_piezas(piezas)
      errores = []
      cuantas = piezas.map { |pieza| pieza[:tipo] }.tally
      errores << "contenido necesita titulo y resumen" unless cuantas[:titulo] && cuantas[:resumen]
      errores << "titulo y resumen van una sola vez" if cuantas.values_at(:titulo, :resumen).compact.any? { |n| n > 1 }

      piezas.each do |pieza|
        if pieza[:mal_escrita]
          errores << "#{pieza[:tipo]} se escribe: #{FORMAS.fetch(pieza[:tipo])}"
          next
        end

        case pieza[:tipo]
        when *Contenido::DE_TEXTO
          errores << "#{pieza[:tipo]} necesita un texto" unless texto?(pieza[:texto])
        when :lista
          completa = pieza[:items].any? && pieza[:items].all? { |item| texto?(item) }
          errores << "lista necesita al menos un elemento" unless completa
        when :imagen
          errores << "imagen necesita url y alt" unless texto?(pieza[:url]) && texto?(pieza[:alt])
        when :boton
          errores << "boton necesita texto y link" unless texto?(pieza[:texto]) && texto?(pieza[:link])
        when :personas
          nil # su forma (un solo marcador) ya la revisó el constructor
        else
          errores << "pieza no permitida: #{pieza[:tipo]}"
        end
      end

      errores
    end

    # Los nombres entre llaves que aparecen en cualquier texto de las piezas: también en
    # los links, las listas y las imágenes.
    def self.marcadores(piezas)
      textos = piezas.flat_map { |pieza| pieza.except(:tipo).values.flatten }
      textos.grep(String).flat_map { |texto| texto.scan(MARCADOR).flatten }.map(&:to_sym).uniq
    end
  end
end
