class Notification
  module Proveedores
    # Interruptores de la demo. Hoy hay uno: si el proveedor simulado está encendido.
    class AjusteDemo < ApplicationRecord
      self.table_name = "ajustes_demo"
      self.primary_key = "clave"
    end
  end
end
