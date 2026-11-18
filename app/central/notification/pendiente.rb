class Notification
  # Un envío pedido que todavía no sale: la caja "Pendientes" del diagrama.
  # Se guarda en la misma transacción que la acción de negocio (D1) y se borra cuando
  # el despachador termina con él.
  class Pendiente < ApplicationRecord
    self.table_name = "pendientes"

    # El orden en que el despachador los toma: lo crítico primero (R13) y, dentro de la
    # misma prioridad, el más antiguo.
    scope :en_orden, -> { order(:prioridad, :creado_en, :id) }

    before_create { self.creado_en ||= Time.current }
  end
end
