module Certificados
  # Acción de negocio: emitir un certificado. Vive en un solo lugar y la usan las dos
  # puertas (pantalla y API), por eso valida y notifica igual por cualquiera (R9).
  module EmitirCertificado
    class Invalida < StandardError; end
    class FallaSimulada < StandardError; end

    Resultado = Data.define(:certificado, :solicitud_id)

    CURSO_MAXIMO = 100

    # `llamar_dos_veces` y `fallar_a_la_mitad` son interruptores de la demo, para mostrar
    # qué pasa si la acción repite el send() o si falla después de pedir la notificación.
    def self.ejecutar(empresa_id:, usuario_id:, curso:, llamar_dos_veces: false, fallar_a_la_mitad: false)
      curso = curso.to_s.strip
      raise Invalida, "falta empresa_id" if empresa_id.blank?
      raise Invalida, "falta usuario_id" if usuario_id.blank?
      raise Invalida, "falta curso" if curso.empty?

      empresa = Empresa.find_by(id: id_entero(empresa_id)) or raise Invalida, "empresa desconocida"
      usuario = empresa.usuarios.find_by(id: id_entero(usuario_id)) or
        raise Invalida, "la persona no pertenece a la empresa"
      raise Invalida, "curso demasiado largo" if curso.length > CURSO_MAXIMO

      # Una sola transacción: el certificado y la notificación se guardan juntos o no se
      # guarda ninguno (D1).
      ActiveRecord::Base.transaction do
        certificado = Certificado.create!(empresa_id: empresa.id, usuario_id: usuario.id, curso: curso)

        notificar = lambda do
          Notification.send "certificado_emitido",
            empresa: empresa.id,
            destinatarios: [usuario.id],
            datos: {
              certificado_id: certificado.id,
              curso: curso,
              link_certificado: "https://ejemplo.test/certificados/#{certificado.id}"
            }
        end

        solicitud_id = notificar.call
        notificar.call if llamar_dos_veces # el segundo pedido queda anotado como duplicado (R2)

        # El error ocurre después de send(): la transacción se deshace completa, y con
        # ella el certificado y la notificación (R14).
        raise FallaSimulada, "la acción falló a la mitad" if fallar_a_la_mitad

        Resultado.new(certificado: certificado, solicitud_id: solicitud_id)
      end
    end

    # Un id puede llegar como número (API) o como texto (formulario). Cualquier otra
    # cosa no es un id, y se trata como desconocido.
    def self.id_entero(valor)
      return valor if valor.is_a?(Integer)

      valor.to_i if valor.is_a?(String) && valor.match?(/\A\d+\z/)
    end
    private_class_method :id_entero
  end
end
