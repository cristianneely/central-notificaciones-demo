# Una persona de una empresa. El correo es texto libre: puede venir vacío o mal escrito,
# y es la central (no quien pide el envío) la que descubre si sirve.
class Usuario < ApplicationRecord
  self.table_name = "usuarios"

  belongs_to :empresa
end
