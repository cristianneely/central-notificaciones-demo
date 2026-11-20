module Demo
  # El simulador: cómo dibuja cada canal una misma notificación. Rellena el contenido y le
  # pide a cada canal su mensaje, sin pasar por send(): no guarda ni entrega nada.
  module Simulador
    NOTIFICACIONES = %w[solicitud_vacaciones saludo_cumpleanos certificado_emitido].freeze
    # Los canales de la tabla de la sección 2.1.5, en ese orden.
    CANALES = %w[email slack whatsapp sms].freeze

    # Si la notificación no es una de las tres, se usa la primera.
    def self.simular(nombre, editados)
      nombre = NOTIFICACIONES.first unless NOTIFICACIONES.include?(nombre)
      definicion = Notification.catalogo.buscar(nombre)
      datos = datos_para(nombre, editados)
      contenido = Notification::Contenido.rellenar(definicion, datos)

      {
        definicion: definicion,
        datos: datos,
        codigo: codigo(definicion),
        canales: CANALES.map do |nombre_canal|
          canal = Notification::Canales.buscar(nombre_canal)
          { nombre: nombre_canal, mensaje: canal.adaptar(contenido), notas: canal.notas(contenido) }
        end
      }
    end

    # Los datos de ejemplo, con lo que la persona editó encima. Solo cuenta un texto no
    # vacío de un dato declarado; lo demás se ignora.
    def self.datos_para(nombre, editados)
      editados = editados.is_a?(Hash) ? editados.to_h.transform_keys(&:to_s) : {}

      ProbarSend.datos_de_ejemplo(nombre).to_h do |dato, ejemplo|
        valor = editados[dato.to_s]
        [dato, valor.is_a?(String) && valor.strip.present? ? valor.strip : ejemplo]
      end
    end

    # La definición tal como la escribió el equipo: el archivo de su clase.
    def self.codigo(definicion)
      File.read(Object.const_source_location(definicion.clase.name).first)
    end

    private_class_method :datos_para, :codigo
  end
end
