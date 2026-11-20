class Notification
  # El catálogo: reúne las definiciones y valida cada una al registrarla (R8).
  # La aplicación usa uno solo (Notification.catalogo); las pruebas pueden crear otro
  # vacío para no ensuciar el de la aplicación.
  class Catalogo
    def initialize
      @definiciones = {}
    end

    # Valida la clase de una notificación y la registra. Si hay errores lanza
    # DefinicionInvalida, con todos juntos, y no registra nada.
    def registrar(clase)
      nombre = clase.identificador
      errores = ValidadorDefinicion.errores(nombre, clase.declarado, nombres_existentes: nombres)
      raise DefinicionInvalida.new(nombre, errores) if errores.any?

      clase.cerrar
      @definiciones[nombre] = Definicion.desde(nombre, clase.declarado, clase: clase)
    end

    def buscar(nombre)
      @definiciones[nombre.to_s]
    end

    # Las definiciones en el orden en que se registraron.
    def todas
      @definiciones.values
    end

    def nombres
      @definiciones.keys
    end

    def vaciar
      @definiciones.clear
    end
  end
end
