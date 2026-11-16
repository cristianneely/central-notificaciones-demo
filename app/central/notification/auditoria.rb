module Notification
  # La auditoría (R10): cada cosa que le pasa a una notificación queda anotada en una
  # fila nueva. Nunca se modifica ni se borra; la base lo impide con disparadores.
  class Auditoria < ApplicationRecord
    self.table_name = "auditoria"

    # Las filas de una solicitud y una persona, en el orden en que ocurrieron.
    scope :recorrido, ->(solicitud_id, usuario_id) {
      where(solicitud_id: solicitud_id, usuario_id: usuario_id).order(:id)
    }

    # Agrega una fila. Los datos de quién y qué salen del pendiente.
    def self.anotar(pendiente, evento, canal: nil, motivo: nil, detalle: {})
      create!(
        solicitud_id: pendiente.solicitud_id,
        empresa_id: pendiente.empresa_id,
        usuario_id: pendiente.usuario_id,
        notificacion: pendiente.notificacion,
        importancia: pendiente.importancia,
        evento: evento,
        canal: canal,
        motivo: motivo,
        detalle: detalle,
        creado_en: Time.current
      )
    end
  end
end
