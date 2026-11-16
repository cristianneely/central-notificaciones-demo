module Notification
  # Lo que una empresa cambió respecto de la política por defecto (R5): una fila con
  # habilitado = no apaga ese canal para esa importancia en esa empresa.
  class PoliticaCliente < ApplicationRecord
    self.table_name = "politicas_cliente"
  end
end
