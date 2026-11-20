class Notification
  module Proveedores
    # El proveedor simulado de Slack, WhatsApp, SMS y push. Ocupa el lugar que tendría cada
    # proveedor real: acepta todo y no guarda nada. Estos canales no están en la política
    # por defecto, así que el despachador no los usa; existen para el simulador.
    module MensajeriaSimulada
      # La única operación de un proveedor. Devuelve un Resultado con un id inventado.
      def self.entregar(canal:, mensaje:, para:)
        Resultado.aceptado("sim-#{canal}-#{SecureRandom.hex(3)}")
      end
    end
  end
end
