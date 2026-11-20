class Notification
  # Las reglas de la API 1.1. Revisa una definición completa y devuelve todos sus errores
  # juntos (no se detiene en el primero), en el orden de la tabla de validaciones.
  module ValidadorDefinicion
    CLAVES = %i[criticidad datos unica_por contenido].freeze
    CLAVES_CONTENIDO = %i[titulo cuerpo accion].freeze
    CLAVES_ACCION = %i[texto link].freeze
    FORMATO_NOMBRE = /\A[a-z][a-z0-9_]*\z/
    MARCADOR = /\{(\w+)\}/

    # Devuelve la lista de mensajes de error; vacía si la definición es válida.
    def self.errores(nombre, opciones, nombres_existentes: [])
      errores = []
      datos = opciones[:datos]
      unica_por = opciones[:unica_por]
      contenido = opciones[:contenido].is_a?(Hash) ? opciones[:contenido] : {}
      accion = contenido[:accion]

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

      # El contenido es neutro: título y cuerpo obligatorios, acción opcional.
      unless texto?(contenido[:titulo]) && texto?(contenido[:cuerpo])
        errores << "contenido necesita titulo y cuerpo"
      end
      if contenido.key?(:accion)
        completa = accion.is_a?(Hash) && texto?(accion[:texto]) && texto?(accion[:link])
        errores << "accion necesita texto y link" unless completa
      end

      # Todo {marcador} del contenido tiene que ser un dato declarado.
      (marcadores(contenido) - declarados).each do |dato|
        errores << "el contenido usa un dato no declarado: #{dato}"
      end

      # Cualquier otra clave se rechaza. Por ejemplo `canales:`: la definición no elige
      # canales, eso lo deciden las políticas (R7).
      sobrantes = opciones.keys - CLAVES
      sobrantes += contenido.keys - CLAVES_CONTENIDO
      sobrantes += accion.keys - CLAVES_ACCION if accion.is_a?(Hash)
      sobrantes.each { |clave| errores << "clave no permitida: #{clave}" }

      errores
    end

    def self.texto?(valor)
      valor.is_a?(String) && !valor.strip.empty?
    end

    # Los nombres entre llaves que aparecen en el título, el cuerpo y la acción.
    def self.marcadores(contenido)
      accion = contenido[:accion].is_a?(Hash) ? contenido[:accion] : {}
      textos = [contenido[:titulo], contenido[:cuerpo], accion[:texto], accion[:link]]
      textos.grep(String).flat_map { |texto| texto.scan(MARCADOR).flatten }.map(&:to_sym).uniq
    end
  end
end
