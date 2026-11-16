require "test_helper"

# El despachador: toma los pendientes y recorre los pasos del documento hasta entregar
# por el canal o dejar anotado por qué no se envió.
class DespachadorTest < ActiveSupport::TestCase
  setup do
    sembrar
    @ana = Usuario.find(1)
  end

  test "13: recorrido feliz, de recibida a entregada, con el correo armado en la bandeja" do
    solicitud = enviar_certificado(@ana, curso: "Excel avanzado")

    assert_equal 1, despachar
    assert_equal %w[recibida decision_enviar enviada], eventos(solicitud)
    assert_equal 0, Notification::Pendiente.count

    correo = bandeja.sole
    assert_equal "ana.soto@ejemplo.test", correo.para
    assert_equal "Tu certificado de Excel avanzado está listo", correo.asunto
    assert_equal "Felicitaciones, terminaste Excel avanzado.", correo.cuerpo
    assert_equal "Descargar", correo.accion_texto
    assert_equal "https://ejemplo.test/certificados/789", correo.accion_link
    assert_match(/\Asim-\d{6}\z/, correo.id_proveedor)

    decision, enviada = recorrido(solicitud).last(2)
    assert_equal "email", decision.canal
    assert_equal "email", enviada.canal
    assert_equal correo.id_proveedor, enviada.detalle["id_proveedor"]

    assert_equal 1, avisar
    assert_equal %w[recibida decision_enviar enviada entregada], eventos(solicitud)
    assert_equal correo.id_proveedor, recorrido(solicitud).last.detalle["id_proveedor"]
  end

  test "13: una notificación sin acción arma un correo sin botón" do
    enviar_saludo(@ana, nombre: "Ana")
    despachar

    correo = bandeja.sole
    assert_equal "¡Feliz cumpleaños, Ana!", correo.asunto
    assert_nil correo.accion_texto
    assert_nil correo.accion_link
  end

  test "13: el proveedor simulado avisa el estado final 2 segundos después de aceptar" do
    freeze_time
    solicitud = enviar_certificado(@ana)
    despachar

    assert_equal 0, Notification::Proveedores::Simulado.enviar_avisos
    travel 2.seconds
    assert_equal 1, Notification::Proveedores::Simulado.enviar_avisos
    assert_equal "entregada", eventos(solicitud).last
    assert_equal 0, Notification::Proveedores::Simulado.enviar_avisos, "no avisa dos veces"
  end

  test "14: un correo que rebota termina en rebotada" do
    solicitud = enviar_certificado(persona("(rebota)", empresa_id: 1))
    despachar
    avisar

    assert_equal %w[recibida decision_enviar enviada rebotada], eventos(solicitud)
  end

  test "15: si el proveedor rechaza ese correo, falla definitivamente y no se reintenta" do
    solicitud = enviar_certificado(persona("(correo inválido)"))
    despachar

    assert_equal %w[recibida decision_enviar fallo_definitivo], eventos(solicitud)
    fallo = recorrido(solicitud).last
    assert_equal "rechazado_por_proveedor", fallo.motivo
    assert_equal "email", fallo.canal
    assert_equal "dirección inválida", fallo.detalle["mensaje"]
    assert_equal 0, Notification::Pendiente.count
    assert_empty bandeja
    assert_equal 0, Notification::EstadoCanal.para("email").fallas_consecutivas
  end

  test "16: sin contacto: persona de otra empresa, id inexistente y persona sin correo" do
    de_otra_empresa = Usuario.find(9)
    sin_correo = persona("(sin correo)")
    solicitud = Notification.send "certificado_emitido",
      empresa: 1,
      destinatarios: [de_otra_empresa.id, 9999, sin_correo.id],
      datos: { certificado_id: 789, curso: "Excel avanzado", link_certificado: "https://ejemplo.test/c/789" }

    assert_equal 3, despachar
    [de_otra_empresa.id, 9999, sin_correo.id].each do |usuario_id|
      assert_equal %w[recibida no_enviada], eventos(solicitud, usuario_id)
      assert_equal "sin_contacto", recorrido(solicitud, usuario_id).last.motivo
    end
    assert_equal 0, Notification::Pendiente.count
    assert_empty bandeja
  end

  test "17: la política del cliente apaga lo opcional y no sale nada" do
    ines = Usuario.find(9) # Minera Los Robles
    solicitud = enviar_saludo(ines, nombre: "Inés")
    despachar

    assert_equal %w[recibida no_enviada], eventos(solicitud)
    assert_equal "politica_cliente", recorrido(solicitud).last.motivo
    assert_equal 0, Notification::Pendiente.count
    assert_empty bandeja
  end

  test "17: la misma empresa sí recibe lo crítico" do
    solicitud = enviar_certificado(Usuario.find(9))
    despachar

    assert_equal "enviada", eventos(solicitud).last
  end

  test "34: una vuelta procesa los 20 pendientes más antiguos, en orden de creación" do
    solicitudes = (1..25).map do |numero|
      travel 1.second
      enviar_certificado(@ana, certificado_id: numero)
    end

    assert_equal 20, despachar

    decisiones = Notification::Auditoria.where(evento: "decision_enviar").order(:id).pluck(:solicitud_id)
    assert_equal solicitudes.first(20), decisiones
    assert_equal solicitudes.last(5), Notification::Pendiente.en_orden.pluck(:solicitud_id)
  end

  test "34: un pendiente que desaparece a mitad de la vuelta no se procesa" do
    enviar_certificado(@ana, certificado_id: 1)
    travel 1.second
    segunda = enviar_certificado(Usuario.find(2), certificado_id: 2)

    # Mientras se entrega el primero, alguien vacía la fila (por ejemplo, "Reiniciar demo").
    canal = Notification::Canales.buscar("email")
    original = canal.method(:adaptar)
    canal.define_singleton_method(:adaptar) do |contenido|
      Notification::Pendiente.where(solicitud_id: segunda).delete_all
      original.call(contenido)
    end

    despachar

    assert_equal ["recibida"], eventos(segunda)
    assert_equal 1, bandeja.size
  ensure
    canal.singleton_class.remove_method(:adaptar)
  end

  test "34: lo crítico sale antes aunque se haya pedido después" do
    informativa = enviar_recordatorio(@ana)
    travel 1.second
    critica = enviar_certificado(@ana)
    despachar

    assert_equal [critica, informativa],
                 Notification::Auditoria.where(evento: "decision_enviar").order(:id).pluck(:solicitud_id)
  end
end
