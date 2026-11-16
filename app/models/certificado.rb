# El resultado de la acción de negocio de ejemplo: "emitir certificado".
class Certificado < ApplicationRecord
  self.table_name = "certificados"

  before_create { self.creado_en ||= Time.current }
end
