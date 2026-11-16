module Notification
  # Políticas de envío: por qué canales sale una notificación.
  # Canales efectivos = política por defecto según la importancia (código)
  #                     menos lo que esa empresa apagó (tabla politicas_cliente).
  module Politicas
    # La política por defecto vigente. Normalmente es la de Configuracion; se puede
    # reemplazar para habilitar un canal nuevo (R7) y volver atrás con restablecer.
    def self.por_defecto
      @por_defecto || Configuracion::POLITICA_POR_DEFECTO
    end

    def self.por_defecto=(politica)
      @por_defecto = politica
    end

    def self.restablecer_por_defecto
      @por_defecto = nil
    end

    # Los canales por los que puede salir una notificación de esa importancia en esa
    # empresa, en orden de preferencia. Puede quedar vacía: entonces no se envía.
    def self.canales_efectivos(empresa_id:, importancia:)
      apagados = PoliticaCliente.where(empresa_id: empresa_id, importancia: importancia.to_s,
                                       habilitado: false).pluck(:canal)
      por_defecto.fetch(importancia.to_s, []) - apagados
    end

    # Guarda lo que una empresa enciende o apaga. Lanza PoliticaInvalida si la importancia
    # o el canal no existen, o si dejaría lo crítico sin ningún canal (R6).
    def self.guardar(empresa_id:, importancia:, canal:, habilitado:)
      politica = PoliticaCliente.find_or_initialize_by(
        empresa_id: empresa_id, importancia: importancia.to_s, canal: canal.to_s
      )
      politica.habilitado = habilitado
      raise PoliticaInvalida, politica.errors.full_messages.first unless politica.save

      politica
    end
  end
end
