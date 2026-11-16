module Cursos
  # Acción de negocio: recordarle a una persona que termine un curso.
  module EnviarRecordatorio
    def self.ejecutar(empresa_id:, usuario_id:, curso:)
      Notification.send "recordatorio_curso",
        empresa: empresa_id.to_i,
        destinatarios: [usuario_id.to_i],
        datos: {
          curso: curso,
          fecha_limite: (Date.current + 7).strftime("%d-%m-%Y"), # hoy, en hora de Chile, más 7 días
          link_curso: "https://ejemplo.test/cursos"
        }
    end
  end
end
