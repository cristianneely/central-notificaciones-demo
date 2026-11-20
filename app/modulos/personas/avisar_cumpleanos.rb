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

      personas = Usuario.where(empresa_id: empresa.id).order(:id).to_a
      hoy = Date.current # en hora de Chile
      cumplen = personas.select { |p| p.nacimiento && [p.nacimiento.month, p.nacimiento.day] == [hoy.month, hoy.day] }
      raise Invalida, "Hoy no hay cumpleaños en #{empresa.nombre}" if cumplen.empty?

      SaludoCumpleanos.send(
        empresa: empresa.id,
        destinatarios: personas.map(&:id), # toda la empresa, también quienes cumplen
        datos: { fecha: hoy.strftime("%d-%m-%Y"),
                 nombres: cumplen.map(&:nombre).to_sentence(words_connector: ", ", last_word_connector: " y ",
                                                            two_words_connector: " y "),
                 cumpleaneros: cumplen.map { |p| { nombre: p.nombre, foto: p.foto.presence || SIN_FOTO } } })
    end
  end
end
