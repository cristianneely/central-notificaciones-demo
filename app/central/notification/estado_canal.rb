module Notification
  # El estado de un canal para los reintentos (R14): cuántas veces seguidas falló su
  # proveedor y cuándo se vuelve a probar.
  class EstadoCanal < ApplicationRecord
    self.table_name = "estado_canales"
    self.primary_key = "canal"

    # El estado de ese canal. Si nunca falló todavía no tiene fila: parte en cero.
    def self.para(canal)
      find_or_initialize_by(canal: canal)
    end
  end
end
