module Notification
  # La auditoría (R10): cada cosa que le pasa a una notificación queda anotada en una
  # fila nueva. Nunca se modifica ni se borra; la base lo impide con disparadores.
  class Auditoria < ApplicationRecord
    self.table_name = "auditoria"

    # Las filas de una solicitud y una persona, en el orden en que ocurrieron.
    scope :recorrido, ->(solicitud_id, usuario_id) {
      where(solicitud_id: solicitud_id, usuario_id: usuario_id).order(:id)
    }

    # Agrega una fila. Los datos de quién y qué salen del envío: un pendiente o una
    # fila anterior del mismo recorrido.
    def self.anotar(envio, evento, canal: nil, motivo: nil, detalle: {})
      create!(
        solicitud_id: envio.solicitud_id,
        empresa_id: envio.empresa_id,
        usuario_id: envio.usuario_id,
        notificacion: envio.notificacion,
        criticidad: envio.criticidad,
        evento: evento,
        canal: canal,
        motivo: motivo,
        detalle: detalle,
        creado_en: Time.current
      )
    end
  end
end
