module Personas
  # Acción de negocio: saludar a una persona en su cumpleaños.
  module SaludarCumpleanos
    def self.ejecutar(empresa_id:, usuario_id:)
      persona = Usuario.find_by(id: usuario_id.to_i)

      Notification.send "saludo_cumpleanos",
        empresa: empresa_id.to_i,
        destinatarios: [usuario_id.to_i],
        datos: { nombre: persona&.nombre, anio: Date.current.year } # el año en curso, en hora de Chile
    end
  end
end
