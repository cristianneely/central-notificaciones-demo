module Personas
  # Acción de negocio: avisar a toda la empresa quién está de cumpleaños hoy. Las personas,
  # sus fotos y sus fechas de nacimiento salen de la base de usuarios.
  module AvisarCumpleanos
    class Invalida < StandardError; end

    # La foto de quien no tiene una.
    SIN_FOTO = "/personas/sin-foto.svg".freeze

    def self.ejecutar(empresa_id:)
      empresa = Empresa.find_by(id: empresa_id.to_i)
      # Una empresa que no existe la rechaza la central, con su propio mensaje.
      return SaludoCumpleanos.send(empresa: empresa_id.to_i, destinatarios: [], datos: {}) unless empresa

      datos = datos_de_hoy(empresa.id) or raise Invalida, "Hoy no hay cumpleaños en #{empresa.nombre}"

      SaludoCumpleanos.send(
        empresa: empresa.id,
        destinatarios: Usuario.where(empresa_id: empresa.id).order(:id).ids, # toda la empresa, también quienes cumplen
        datos: datos)
    end

    # Los datos del aviso de hoy en una empresa, o nil si nadie está de cumpleaños. El
    # simulador los usa también, para mostrar a quienes cumplen hoy sin enviar nada.
    def self.datos_de_hoy(empresa_id)
      hoy = Date.current # en hora de Chile
      cumplen = Usuario.where(empresa_id: empresa_id).order(:id).select do |persona|
        persona.nacimiento && [persona.nacimiento.month, persona.nacimiento.day] == [hoy.month, hoy.day]
      end
      return nil if cumplen.empty?

      { fecha: hoy.strftime("%d-%m-%Y"),
        cumpleaneros: cumplen.map { |persona| { nombre: persona.nombre, foto: persona.foto.presence || SIN_FOTO } } }
    end
  end
end
