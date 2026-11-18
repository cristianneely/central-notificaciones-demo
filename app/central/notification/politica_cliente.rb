module Notification
  # Lo que una empresa cambió respecto de la política por defecto (R5): una fila con
  # habilitado = no apaga ese canal para esa criticidad en esa empresa.
  class PoliticaCliente < ApplicationRecord
    self.table_name = "politicas_cliente"

    validate :reglas

    private

    # Se revisa en este orden y se informa el primer problema.
    def reglas
      if !Configuracion::PRIORIDADES.key?(criticidad.to_s.to_sym)
        errors.add(:base, "criticidad desconocida: #{criticidad}")
      elsif !Canales.nombres.include?(canal)
        errors.add(:base, "canal desconocido: #{canal}")
      elsif deja_lo_critico_sin_canal?
        # R6: lo crítico siempre tiene al menos un canal. No hay excepción por cliente.
        errors.add(:base, "Una política no puede dejar lo crítico sin canal")
      end
    end

    def deja_lo_critico_sin_canal?
      return false unless criticidad == "critica" && !habilitado

      otros_apagados = self.class.where(empresa_id: empresa_id, criticidad: "critica", habilitado: false)
                           .where.not(canal: canal).pluck(:canal)
      (Politicas.por_defecto.fetch("critica", []) - otros_apagados - [canal]).empty?
    end
  end
end
