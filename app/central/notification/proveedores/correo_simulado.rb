class Notification
  module Proveedores
    # Un correo que el proveedor simulado aceptó: su "bandeja". Guarda el correo completo
    # porque representa lo que tendría el proveedor real; no es parte de la central.
    class CorreoSimulado < ApplicationRecord
      self.table_name = "correos_simulados"
    end
  end
end
