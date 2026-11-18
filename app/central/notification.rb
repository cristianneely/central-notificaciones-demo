# La central de notificaciones. Los módulos de los equipos solo conocen dos operaciones:
#
#   class CertificadoEmitido < Notification   (API 1.1) — declara una notificación.
#   CertificadoEmitido.send(...)              (API 1.2) — pide enviarla.
#
# Todo lo demás (despachador, políticas, canales, proveedor, receptor, auditoría) vive en
# app/central/notification/ y es interno de la central.
class Notification
  # Una definición que no cumple las reglas de 1.1. Trae todos los problemas juntos.
  class DefinicionInvalida < StandardError
    attr_reader :errores

    def initialize(nombre, errores)
      @errores = errores
      super("#{nombre}: #{errores.join('; ')}")
    end
  end

  # Un pedido de envío que no cumple las reglas de 1.2.
  class SolicitudInvalida < StandardError; end

  # Una política de cliente que no se puede guardar (R6).
  class PoliticaInvalida < StandardError; end

  class << self
    # --- API 1.1: lo que declara cada notificación -----------------------------------
    # Las cuatro declaraciones son obligatorias. Aquí solo se anotan; las revisa el
    # catálogo al arrancar, todas juntas (R8).

    def criticidad(valor) = declarar(:criticidad, valor)
    def datos(*nombres) = declarar(:datos, nombres)
    def unica_por(*nombres) = declarar(:unica_por, nombres)
    def contenido(**campos) = declarar(:contenido, campos)

    # Lo declarado en la clase, tal cual, para que el catálogo lo valide.
    def declarado
      @declarado ||= {}
    end

    # El nombre con que la notificación queda en pendientes, claves y auditoría: el de
    # la clase, en minúsculas con guion bajo (CertificadoEmitido → certificado_emitido).
    def identificador
      name.to_s.demodulize.underscore
    end

    # El catálogo de la aplicación: todas las definiciones registradas. Es uno solo,
    # compartido por la clase base y por cada notificación.
    def catalogo
      @@catalogo ||= Catalogo.new
    end

    # El catálogo ya validó esta clase: desde ahora no admite declaraciones desconocidas.
    def cerrar
      @cerrada = true
    end

    # --- API 1.2: pedir el envío ------------------------------------------------------
    #
    # Solo valida, guarda y responde (R13): no entrega nada. Por cada destinatario deja
    # una clave única, un pendiente y la anotación "recibida", todo dentro de la misma
    # transacción que la acción de negocio que la llamó (D1): si la acción se deshace,
    # la notificación también. La entrega la hace después el despachador.
    #
    # Van usuarios, no correos: la central es la que busca el contacto.
    # Devuelve el id de la solicitud (un UUID), común a todos los destinatarios.
    #
    # Sobre el nombre: el diseño lo llama `send` y se respetó; en producción se llamaría
    # `deliver`, la convención de Rails, para no pisar un método del lenguaje (en Ruby
    # todo objeto ya trae un `send`). Por eso aquí `send` con un símbolo sigue siendo el
    # de Ruby, y el trabajo lo hace `deliver`.
    def send(*argumentos, **opciones, &bloque)
      return super if argumentos.any?

      deliver(**opciones)
    end

    def deliver(empresa:, destinatarios:, datos:)
      # Solo se puede enviar una notificación que el catálogo validó.
      definicion = catalogo.buscar(identificador)
      definicion = nil unless definicion&.clase == self
      datos = validar_solicitud(definicion, empresa, destinatarios, datos)

      solicitud_id = SecureRandom.uuid
      ahora = Time.current

      # Si la acción de negocio ya abrió una transacción, esto se suma a ella; si no,
      # abre la suya.
      ActiveRecord::Base.transaction do
        destinatarios.each do |usuario_id|
          pendiente = Pendiente.new(
            solicitud_id: solicitud_id,
            notificacion: definicion.nombre,
            empresa_id: empresa,
            usuario_id: usuario_id,
            datos: datos,
            criticidad: definicion.criticidad.to_s,
            prioridad: definicion.prioridad
          )

          # La clave: nombre de la notificación, usuario y los valores de unica_por (R2).
          clave = [definicion.nombre, usuario_id, *definicion.unica_por.map { |dato| datos[dato] }].join("|")
          detalle = { datos: datos, origen: Contexto.origen, clave: clave }

          if ClaveUnica.reservar(clave, ahora: ahora)
            pendiente.save!
            Auditoria.anotar(pendiente, "recibida", detalle: detalle.merge(version: definicion.version))
          else
            # Ya se había pedido lo mismo: no se crea pendiente, pero queda anotado.
            Auditoria.anotar(pendiente, "duplicada", motivo: "clave_repetida", detalle: detalle)
          end
        end
      end

      solicitud_id
    end

    private

    def declarar(campo, valor)
      declarado[campo] = valor
    end

    # Una declaración que la central no conoce (por ejemplo `canales [:email]`) no rompe
    # la carga de la clase: se anota, y el catálogo la informa junto con los demás
    # errores. Solo mientras la clase no ha sido validada; después, un método que no
    # existe es un error de Ruby como cualquier otro.
    def method_missing(nombre, *argumentos, &bloque)
      return super if @cerrada || equal?(Notification) || argumentos.empty? || bloque

      declarar(nombre, argumentos.one? ? argumentos.first : argumentos)
    end

    def respond_to_missing?(*)
      false
    end

    # Las reglas de 1.2, en el orden de la tabla de validaciones. Lanza SolicitudInvalida
    # en la primera que no se cumple. Devuelve los datos con sus claves normalizadas.
    def validar_solicitud(definicion, empresa, destinatarios, datos)
      raise SolicitudInvalida, "notificación desconocida: #{identificador}" unless definicion
      raise SolicitudInvalida, "empresa desconocida: #{empresa}" unless id?(empresa) && Empresa.exists?(id: empresa)

      lista_valida = destinatarios.is_a?(Array) && destinatarios.any? &&
                     destinatarios.all? { |usuario_id| id?(usuario_id) } &&
                     destinatarios.uniq == destinatarios
      unless lista_valida
        raise SolicitudInvalida, "destinatarios debe ser una lista de ids de usuario sin repetir"
      end

      tope = Configuracion::TOPE_DESTINATARIOS
      if destinatarios.size > tope
        raise SolicitudInvalida, "destinatarios supera el tope de #{tope} por llamada"
      end

      # Los datos tienen que ser exactamente los declarados: ni uno menos, ni uno más
      # (un dato de más suele ser un error de tipeo).
      datos = datos.to_h.transform_keys(&:to_sym)
      (definicion.datos - datos.keys).each { |dato| raise SolicitudInvalida, "falta el dato: #{dato}" }
      (datos.keys - definicion.datos).each { |dato| raise SolicitudInvalida, "dato no declarado: #{dato}" }
      datos.each do |dato, valor|
        vacio = valor.nil? || (valor.is_a?(String) && valor.strip.empty?)
        raise SolicitudInvalida, "el dato #{dato} está vacío" if vacio
      end

      datos
    end

    # Un id es un entero positivo que cabe en la base (64 bits).
    def id?(valor)
      valor.is_a?(Integer) && valor.between?(1, 2**63 - 1)
    end
  end
end
