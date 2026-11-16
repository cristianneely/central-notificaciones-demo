module Notification
  # El catálogo: reúne las definiciones y valida cada una al registrarla (R8).
  # La aplicación usa uno solo (Notification.catalogo); las pruebas pueden crear otro
  # vacío para no ensuciar el de la aplicación.
  class Catalogo
    def initialize
      @definiciones = {}
    end

    # Valida y registra. Si hay errores lanza DefinicionInvalida y no registra nada.
    def registrar(nombre, **opciones)
      errores = ValidadorDefinicion.errores(nombre, opciones, nombres_existentes: nombres)
      raise DefinicionInvalida.new(nombre, errores) if errores.any?

      @definiciones[nombre] = Definicion.desde(nombre, opciones)
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
