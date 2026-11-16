module Notification
  # Los canales por los que la central sabe entregar. Hoy hay uno: email.
  # Agregar otro es registrarlo aquí y habilitarlo en la política; las definiciones de
  # los equipos no cambian (R7).
  module Canales
    def self.registro
      @registro ||= { "email" => Email.new }
    end

    def self.registrar(canal)
      registro[canal.nombre] = canal
    end

    def self.buscar(nombre)
      registro.fetch(nombre)
    end

    def self.nombres
      registro.keys
    end

    def self.quitar(nombre)
      registro.delete(nombre)
    end
  end
end
