module Demo
  # Acción de laboratorio: llama a send() con lo que se escribió en el formulario
  # "Probar send()" del catálogo. Existe para ejercer la API 1.2 a mano y ver sus
  # rechazos. Es esta acción, y no el controlador, la que llama a send() (R9).
  module ProbarSend
    class Invalida < StandardError; end

    def self.ejecutar(notificacion:, empresa_id:, destinatarios_texto:, datos_texto:)
      datos = leer_datos(datos_texto)

      # "1, 2" → [1, 2]. Lo que no sea un número se deja tal cual, para que sea send()
      # quien lo rechace con su propio mensaje.
      destinatarios = destinatarios_texto.to_s.split(",", -1).map { |texto| entero_o_texto(texto.strip) }

      # El formulario manda el nombre como texto; en el código se escribe la clase, y
      # una que no existe la rechaza el propio lenguaje.
      definicion = Notification.catalogo.buscar(notificacion.to_s) or
        raise Invalida, "notificación desconocida: #{notificacion}"

      definicion.clase.send(
        empresa: entero_o_texto(empresa_id.to_s),
        destinatarios: destinatarios,
        datos: datos
      )
    end

    # Datos válidos para rellenar el formulario según la notificación elegida.
    def self.datos_de_ejemplo(notificacion)
      case notificacion
      when "certificado_emitido"
        { certificado_id: 1001, curso: "Excel avanzado",
          link_certificado: "https://ejemplo.test/certificados/1001" }
      when "recordatorio_curso"
        { curso: "Excel básico", fecha_limite: (Date.current + 7).strftime("%d-%m-%Y"),
          link_curso: "https://ejemplo.test/cursos" }
      when "encuesta_satisfaccion"
        { curso: "Excel básico", link_encuesta: "https://ejemplo.test/encuesta" }
      when "saludo_cumpleanos"
        { nombre: "Ana", anio: Date.current.year }
      when "solicitud_vacaciones"
        { solicitud_id: 55, solicitante: "Ana Soto", desde: "02-12-2026", hasta: "06-12-2026",
          dias_habiles: 5, link_solicitud: "https://ejemplo.test/vacaciones/55" }
      else
        {}
      end
    end

    def self.leer_datos(texto)
      datos = JSON.parse(texto.to_s)
      raise Invalida, "datos debe ser un objeto JSON" unless datos.is_a?(Hash)

      datos
    rescue JSON::ParserError
      raise Invalida, "datos no es JSON válido"
    end

    def self.entero_o_texto(texto)
      texto.match?(/\A\d+\z/) ? texto.to_i : texto
    end

    private_class_method :leer_datos, :entero_o_texto
  end
end
