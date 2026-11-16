module Cursos
  # Acción de negocio: pedirle a una persona su opinión sobre un curso.
  module EnviarEncuesta
    def self.ejecutar(empresa_id:, usuario_id:, curso:)
      Notification.send "encuesta_satisfaccion",
        empresa: empresa_id.to_i,
        destinatarios: [usuario_id.to_i],
        datos: { curso: curso, link_encuesta: "https://ejemplo.test/encuesta" }
    end
  end
end
