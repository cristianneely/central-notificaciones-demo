module Demo
  # El simulador: cómo dibuja cada canal una misma notificación. Rellena el contenido y le
  # pide a cada canal su mensaje, sin pasar por send(): no guarda ni entrega nada. Lee de la
  # base a la persona elegida (su foto y su contacto) y, en el cumpleaños, a quienes cumplen.
  module Simulador
    NOTIFICACIONES = %w[solicitud_vacaciones saludo_cumpleanos certificado_emitido].freeze
    # Los canales de la tabla de la sección 2.1.5, en ese orden.
    CANALES = %w[email slack whatsapp sms push].freeze
    # La empresa para probar en vivo: de ahí se eligen la persona y los cumpleañeros.
    EMPRESA = 1
    # Los datos que no se escriben a mano: salen de la base de usuarios.
    DE_LA_BASE = { "saludo_cumpleanos" => %i[nombres cumpleaneros] }.freeze

    # Si la notificación no es una de las tres, se usa la primera; si la persona no es de la
    # empresa, la primera de la empresa.
    def self.simular(nombre, editados, para = nil)
      nombre = NOTIFICACIONES.first unless NOTIFICACIONES.include?(nombre)
      definicion = Notification.catalogo.buscar(nombre)
      datos = datos_para(nombre, editados)
      contenido = Notification::Contenido.rellenar(definicion, datos)
      personas = Usuario.where(empresa_id: EMPRESA).order(:id).to_a
      persona = personas.find { |p| p.id.to_s == para.to_s } || personas.first

      {
        definicion: definicion,
        datos: datos,
        de_la_base: DE_LA_BASE.fetch(nombre, []),
        # Si hoy nadie cumple años en la empresa, los cumpleañeros son los de ejemplo.
        cumpleanos_de_ejemplo: DE_LA_BASE.key?(nombre) && Personas::AvisarCumpleanos.datos_de_hoy(EMPRESA).nil?,
        codigo: codigo(definicion),
        personas: personas,
        destinatario: destinatario(persona),
        canales: CANALES.map do |nombre_canal|
          canal = Notification::Canales.buscar(nombre_canal)
          { nombre: nombre_canal, mensaje: canal.adaptar(contenido), notas: canal.notas(contenido),
            contacto: canal.contacto, para: persona && Notification::Contactos.buscar(persona, canal.contacto) }
        end
      }
    end

    # La persona elegida, como la ve la central: su foto (o la de respaldo) y su correo.
    def self.destinatario(persona)
      return nil unless persona

      { id: persona.id, nombre: persona.nombre,
        foto: persona.foto.presence || Personas::AvisarCumpleanos::SIN_FOTO,
        correo: Notification::Contactos.buscar(persona, :correo) }
    end

    # Los datos de ejemplo, con lo que la persona editó encima. Solo cuenta un texto no
    # vacío de un dato declarado; lo demás se ignora. Lo que sale de la base no se edita.
    def self.datos_para(nombre, editados)
      editados = editados.is_a?(Hash) ? editados.to_h.transform_keys(&:to_s) : {}
      de_la_base = DE_LA_BASE.fetch(nombre, [])
      ejemplo = ProbarSend.datos_de_ejemplo(nombre)
      ejemplo = ejemplo.merge(Personas::AvisarCumpleanos.datos_de_hoy(EMPRESA).to_h) if de_la_base.any?

      ejemplo.to_h do |dato, valor_de_ejemplo|
        valor = editados[dato.to_s] unless de_la_base.include?(dato)
        [dato, valor.is_a?(String) && valor.strip.present? ? valor.strip : valor_de_ejemplo]
      end
    end

    # La definición tal como la escribió el equipo: el archivo de su clase.
    def self.codigo(definicion)
      File.read(Object.const_source_location(definicion.clase.name).first)
    end

    private_class_method :datos_para, :codigo, :destinatario
  end
end
