# La central de notificaciones. Los módulos de los equipos solo conocen dos operaciones:
#
#   Notification.define  (API 1.1) — declara una notificación en el catálogo.
#   Notification.send    (API 1.2) — pide enviarla.
#
# Todo lo demás (despachador, políticas, canales, proveedor, receptor, auditoría) vive en
# app/central/notification/ y es interno de la central.
module Notification
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

  # API 1.1 — Declara una notificación. La valida y la deja en el catálogo (R8).
  # Si la definición está mal escrita lanza DefinicionInvalida: la app no arranca.
  def self.define(nombre, **opciones)
    catalogo.registrar(nombre, **opciones)
  end

  # El catálogo de la aplicación: todas las definiciones registradas.
  def self.catalogo
    @catalogo ||= Catalogo.new
  end

  # API 1.2 — Pide enviar una notificación a una o más personas de una empresa.
  #
  # Solo valida, guarda y responde (R13): no entrega nada. Por cada destinatario deja una
  # clave única, un pendiente y la anotación "recibida", todo dentro de la misma
  # transacción que la acción de negocio que la llamó (D1): si la acción se deshace, la
  # notificación también. La entrega la hace después el despachador.
  #
  # Van usuarios, no correos: la central es la que busca el contacto.
  # Devuelve el id de la solicitud (un UUID), común a todos los destinatarios.
  #
  # Sobre el nombre: el enunciado lo llama `send` y se respetó; en producción se llamaría
  # `deliver`, la convención de Rails, para no pisar un método del lenguaje (en Ruby todo
  # objeto ya trae un `send`). Aquí es seguro porque Notification es un módulo propio.
  def self.send(nombre, empresa:, destinatarios:, datos:)
    definicion = catalogo.buscar(nombre)
    datos = validar_solicitud(nombre, definicion, empresa, destinatarios, datos)

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
          importancia: definicion.importancia.to_s,
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

  # Las reglas de 1.2, en el orden de la tabla de validaciones. Lanza SolicitudInvalida
  # en la primera que no se cumple. Devuelve los datos con sus claves normalizadas.
  def self.validar_solicitud(nombre, definicion, empresa, destinatarios, datos)
    raise SolicitudInvalida, "notificación desconocida: #{nombre}" unless definicion
    raise SolicitudInvalida, "empresa desconocida: #{empresa}" unless id?(empresa) && Empresa.exists?(id: empresa)

    lista_valida = destinatarios.is_a?(Array) && destinatarios.any? &&
                   destinatarios.all? { |usuario_id| id?(usuario_id) } &&
                   destinatarios.uniq == destinatarios
    unless lista_valida
      raise SolicitudInvalida, "destinatarios debe ser una lista de ids de usuario sin repetir"
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
  def self.id?(valor)
    valor.is_a?(Integer) && valor.between?(1, 2**63 - 1)
  end

  private_class_method :validar_solicitud, :id?
end
