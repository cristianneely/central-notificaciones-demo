class Notification
  # Una clave única por notificación y persona (R2). El índice único de la tabla es el
  # que impide el duplicado: dos pedidos iguales no pueden guardar la misma clave.
  class ClaveUnica < ApplicationRecord
    self.table_name = "claves_unicas"
    self.primary_key = "clave"

    # Intenta reservar la clave. Devuelve true si quedó reservada y false si ya existía.
    # Es una sola instrucción a la base ("inserta, y si ya está no hagas nada"), así que
    # dos pedidos simultáneos no pueden ganar los dos.
    def self.reservar(clave, ahora:)
      where(clave: clave).where(expira_en: ..ahora).delete_all # una clave vencida ya no bloquea

      vence = ahora + Configuracion::BLOQUEO_DUPLICADOS
      insert({ clave: clave, expira_en: vence }, unique_by: :clave, returning: :clave).rows.any?
    end
  end
end
