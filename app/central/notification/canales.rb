class Notification
  # Los canales por los que la central sabe entregar. Agregar uno es registrarlo aquí y
  # habilitarlo en la política; las definiciones de los equipos no cambian (R7).
  # Email es el único real. Slack, WhatsApp, SMS y push son simulados y no están en la
  # política por defecto: el simulador los usa para mostrar cómo dibuja cada uno las mismas
  # piezas.
  module Canales
    def self.registro
      @registro ||= [Email.new, Slack.new, Whatsapp.new, Sms.new, Push.new].to_h { |canal| [canal.nombre, canal] }
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
