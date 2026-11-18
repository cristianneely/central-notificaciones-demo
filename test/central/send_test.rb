require "test_helper"

# API 1.2 del documento: el send() de cada notificación. Solo valida, guarda y responde (R13);
# no entrega nada: eso lo hace después el despachador.
class SendTest < ActiveSupport::TestCase
  UUID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

  setup do
    sembrar
    @ana = Usuario.find(1)
    @bruno = Usuario.find(2)
    @datos = { certificado_id: 789, curso: "Excel avanzado",
               link_certificado: "https://ejemplo.test/certificados/789" }
  end

  # Llama a send() con un certificado válido, cambiando lo que la prueba pida.
  def enviar(clase: CertificadoEmitido, empresa: 1, destinatarios: [@ana.id], datos: @datos)
    clase.send(empresa: empresa, destinatarios: destinatarios, datos: datos)
  end

  def assert_rechaza(mensaje, **cambios)
    antes = conteos_de_send
    error = assert_raises(Notification::SolicitudInvalida) { enviar(**cambios) }

    assert_equal mensaje, error.message
    assert_equal antes, conteos_de_send, "un send() rechazado no debe guardar nada"
  end

  test "4: send() feliz guarda la clave, el pendiente y la anotación recibida" do
    solicitud = enviar

    assert_match UUID, solicitud
    assert_equal ["certificado_emitido|1|789"], Notification::ClaveUnica.pluck(:clave)

    pendiente = Notification::Pendiente.sole
    assert_equal solicitud, pendiente.solicitud_id
    assert_equal "certificado_emitido", pendiente.notificacion
    assert_equal 0, pendiente.prioridad
    assert_equal "critica", pendiente.criticidad
    assert_equal "Excel avanzado", pendiente.datos["curso"]

    fila = Notification::Auditoria.sole
    assert_equal "recibida", fila.evento
    assert_equal [solicitud, 1, 1, "certificado_emitido", "critica"],
                 [fila.solicitud_id, fila.empresa_id, fila.usuario_id, fila.notificacion, fila.criticidad]
    assert_equal Notification.catalogo.buscar("certificado_emitido").version, fila.detalle["version"]
    assert_equal "interno", fila.detalle["origen"]
    assert_equal "certificado_emitido|1|789", fila.detalle["clave"]
    assert_equal "Excel avanzado", fila.detalle["datos"]["curso"]
  end

  test "4: la prioridad del pendiente sale de la criticidad de la definición" do
    enviar_recordatorio(@ana)
    SaludoCumpleanos.send(empresa: 1, destinatarios: [@ana.id],
                                           datos: { nombre: "Ana", anio: 2026 })

    assert_equal [1, 2], Notification::Pendiente.order(:id).pluck(:prioridad)
  end

  test "4: acepta los datos con claves de texto" do
    enviar(datos: @datos.transform_keys(&:to_s))

    assert_equal 1, Notification::Pendiente.count
  end

  test "5: una clase que no está en el catálogo es una notificación desconocida" do
    sin_registrar = Class.new(Notification)
    Module.new.const_set("NoExiste", sin_registrar)

    assert_rechaza "notificación desconocida: no_existe", clase: sin_registrar
    assert_rechaza "notificación desconocida: notification", clase: Notification
  end

  test "38: send con un símbolo se comporta como el send de Ruby" do
    assert_equal "CertificadoEmitido", CertificadoEmitido.send(:name)
    assert_equal "certificado_emitido", CertificadoEmitido.public_send(:identificador)
    assert_not CertificadoEmitido.respond_to?(:canales)
  end

  test "38: un método desconocido sobre una clase ya validada es un error de Ruby" do
    assert_raises(NoMethodError) { CertificadoEmitido.sennd(empresa: 1) }
    assert_raises(NoMethodError) { CertificadoEmitido.canales [:email] }
    assert_equal 4, Notification.catalogo.todas.size
    assert_equal %i[contenido criticidad datos unica_por], CertificadoEmitido.declarado.keys.sort
  end

  test "38: deliver hace lo mismo que send" do
    solicitud = CertificadoEmitido.deliver(empresa: 1, destinatarios: [@ana.id], datos: @datos)

    assert_match UUID, solicitud
    assert_equal 1, Notification::Pendiente.count
  end

  test "38: send sin un parámetro obligatorio no guarda nada" do
    antes = conteos_de_send

    assert_raises(ArgumentError) { CertificadoEmitido.send(empresa: 1) }
    assert_equal antes, conteos_de_send
  end

  test "5: empresa desconocida" do
    assert_rechaza "empresa desconocida: 999", empresa: 999
  end

  test "5: destinatarios vacío" do
    assert_rechaza "destinatarios debe ser una lista de ids de usuario sin repetir", destinatarios: []
  end

  test "5: destinatarios repetidos" do
    assert_rechaza "destinatarios debe ser una lista de ids de usuario sin repetir", destinatarios: [1, 1]
  end

  test "5: destinatarios que no son ids enteros" do
    assert_rechaza "destinatarios debe ser una lista de ids de usuario sin repetir", destinatarios: ["a"]
    assert_rechaza "destinatarios debe ser una lista de ids de usuario sin repetir", destinatarios: "1"
  end

  test "5: destinatarios con ids imposibles (cero, negativos o enormes)" do
    mensaje = "destinatarios debe ser una lista de ids de usuario sin repetir"

    assert_rechaza mensaje, destinatarios: [0]
    assert_rechaza mensaje, destinatarios: [-1]
    assert_rechaza mensaje, destinatarios: [99_999_999_999_999_999_999]
  end

  test "5: una empresa con un id enorme es una empresa desconocida" do
    assert_rechaza "empresa desconocida: 99999999999999999999", empresa: 99_999_999_999_999_999_999
  end

  test "5: falta un dato declarado" do
    assert_rechaza "falta el dato: curso", datos: @datos.except(:curso)
  end

  test "5: sobra un dato no declarado" do
    assert_rechaza "dato no declarado: extra", datos: @datos.merge(extra: 1)
  end

  test "5: un dato vacío" do
    assert_rechaza "el dato curso está vacío", datos: @datos.merge(curso: "")
    assert_rechaza "el dato curso está vacío", datos: @datos.merge(curso: "   ")
    assert_rechaza "el dato curso está vacío", datos: @datos.merge(curso: nil)
  end

  test "5: un send() inválido deshace también lo que la acción ya había guardado" do
    assert_raises(Notification::SolicitudInvalida) do
      ActiveRecord::Base.transaction do
        Certificado.create!(empresa_id: 1, usuario_id: 1, curso: "Excel avanzado")
        enviar(datos: @datos.except(:curso))
      end
    end

    assert_equal 0, Certificado.count
  end

  test "6: el mismo send() dos veces deja un solo pendiente y anota la segunda como duplicada" do
    primera = enviar
    segunda = enviar

    assert_match UUID, primera
    assert_match UUID, segunda
    assert_not_equal primera, segunda
    assert_equal 1, Notification::Pendiente.count
    assert_equal ["recibida"], eventos(primera)
    assert_equal ["duplicada"], eventos(segunda)

    duplicada = recorrido(segunda).sole
    assert_equal "clave_repetida", duplicada.motivo
    assert_equal "certificado_emitido|1|789", duplicada.detalle["clave"]
    assert_equal "interno", duplicada.detalle["origen"]
  end

  test "7: mismo unica_por con otro dato sigue siendo duplicado" do
    enviar
    segunda = enviar(datos: @datos.merge(link_certificado: "https://ejemplo.test/otro-link"))

    assert_equal ["duplicada"], eventos(segunda)
    assert_equal 1, Notification::Pendiente.count
  end

  test "8: distinto unica_por no es duplicado" do
    enviar_recordatorio(@ana, fecha_limite: "22-11-2026")
    enviar_recordatorio(@ana, fecha_limite: "23-11-2026")

    assert_equal 2, Notification::Pendiente.count
    assert_equal ["recordatorio_curso|1|Excel básico|22-11-2026",
                  "recordatorio_curso|1|Excel básico|23-11-2026"],
                 Notification::ClaveUnica.order(:clave).pluck(:clave)
  end

  test "9: una clave vencida deja pasar el mismo send()" do
    enviar
    travel 24.hours + 1.minute
    segunda = enviar

    assert_equal 2, Notification::Pendiente.count
    assert_equal ["recibida"], eventos(segunda)
    assert_equal 1, Notification::ClaveUnica.count
  end

  test "9: una clave que todavía no vence sigue bloqueando" do
    enviar
    travel 23.hours + 59.minutes
    segunda = enviar

    assert_equal ["duplicada"], eventos(segunda)
  end

  test "10: varios destinatarios y uno ya lo había recibido" do
    enviar(destinatarios: [@ana.id])
    solicitud = enviar(destinatarios: [@ana.id, @bruno.id])

    assert_equal 2, Notification::Pendiente.count
    assert_equal [@bruno.id], Notification::Pendiente.where(solicitud_id: solicitud).pluck(:usuario_id)
    assert_equal ["duplicada"], eventos(solicitud, @ana.id)
    assert_equal ["recibida"], eventos(solicitud, @bruno.id)
  end
end
