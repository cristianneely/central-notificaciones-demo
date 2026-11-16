# Una empresa cliente. En la demo son tres, todas ficticias.
class Empresa < ApplicationRecord
  self.table_name = "empresas"

  has_many :usuarios
end
