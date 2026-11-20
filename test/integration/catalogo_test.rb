require "test_helper"

# La pantalla del catálogo: muestra las definiciones (R8) y permite probar a mano las
# dos APIs: una definición inválida (1.1) y una llamada a send() (1.2).
class CatalogoPantallaTest < ActionDispatch::IntegrationTest
  UUID = /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/

  setup { sembrar }

  def probar_send(**cambios)
    datos = { certificado_id: 1001, curso: "Excel avanzado", link_certificado: "https://ejemplo.test/c/1001" }
    post "/catalogo/probar_send", params: {
      notificacion: "certificado_emitido", empresa_id: 1, destinatarios: "1", datos: datos.to_json
    }.merge(cambios)
  end

  def assert_send_rechaza(mensaje, **cambios)
    antes = conteos_de_send
    probar_send(**cambios)

    assert_response :ok
    assert_select ".resultado.error", text: mensaje
    assert_equal antes, conteos_de_send, "un send() rechazado no guarda nada"
  end

  test "la pantalla lista las cinco definiciones con su versión" do
    get "/catalogo"

    assert_select ".definicion", count: 5
    Notification.catalogo.todas.each do |definicion|
      assert_includes response.body, definicion.nombre
      assert_includes response.body, definicion.version
    end
    assert_includes response.body, "Tu certificado de {curso} está listo"
    assert_select "select[name=notificacion] option", count: 6
    assert_select "select[name=notificacion] option", text: "una_que_no_existe"
    assert_select "input[name=destinatarios][value='1']"
  end

  test "probar una definición inválida muestra sus errores y no la registra" do
    post "/catalogo/definicion_invalida"

    assert_response :ok
    ["criticidad debe ser :critica, :informativa u :opcional", "unica_por es obligatorio",
     "pieza no permitida: video", "el contenido usa un dato no declarado: dato_inexistente",
     "clave no permitida: canales"].each do |mensaje|
      assert_select ".errores-definicion li", text: mensaje
    end
    assert_equal 5, Notification.catalogo.todas.size
  end

  test "36: probar send() con datos válidos devuelve la solicitud y deja un pendiente" do
    probar_send

    assert_response :ok
    assert_select ".resultado", text: /\ASolicitud #{UUID}\z/
    pendiente = Notification::Pendiente.sole
    assert_includes response.body, pendiente.solicitud_id
    assert_equal "web", Notification::Auditoria.sole.detalle["origen"]
  end

  test "36: probar send() sin un dato" do
    assert_send_rechaza "falta el dato: curso",
                        datos: { certificado_id: 1001, link_certificado: "https://ejemplo.test/c/1001" }.to_json
  end

  test "36: probar send() con una notificación que no existe" do
    assert_send_rechaza "notificación desconocida: una_que_no_existe", notificacion: "una_que_no_existe"
  end

  test "36: probar send() con datos que no son JSON" do
    assert_send_rechaza "datos no es JSON válido", datos: "{mal"
    assert_send_rechaza "datos no es JSON válido", datos: ""
  end

  test "36: probar send() con datos que son JSON pero no un objeto" do
    assert_send_rechaza "datos debe ser un objeto JSON", datos: "[1]"
    assert_send_rechaza "datos debe ser un objeto JSON", datos: "\"texto\""
  end

  test "36: probar send() con destinatarios mal escritos" do
    mensaje = "destinatarios debe ser una lista de ids de usuario sin repetir"

    assert_send_rechaza mensaje, destinatarios: "abc"
    assert_send_rechaza mensaje, destinatarios: ""
    assert_send_rechaza mensaje, destinatarios: "1,,2"
    assert_send_rechaza mensaje, destinatarios: "1, 1"
  end

  test "36: probar send() acepta varios destinatarios separados por coma" do
    probar_send(destinatarios: " 1, 2 ")

    assert_equal [1, 2], Notification::Pendiente.order(:id).pluck(:usuario_id)
  end

  test "36: probar send() con una empresa que no existe" do
    assert_send_rechaza "empresa desconocida: 999", empresa_id: "999"
    assert_send_rechaza "empresa desconocida: abc", empresa_id: "abc"
  end

  test "36: probar send() con un destinatario enorme o con campos con forma de objeto" do
    assert_send_rechaza "destinatarios debe ser una lista de ids de usuario sin repetir",
                        destinatarios: "99999999999999999999"

    post "/catalogo/probar_send", params: { notificacion: { a: 1 }, empresa_id: { a: 1 },
                                            destinatarios: { a: 1 }, datos: { a: 1 } }
    assert_response :ok
    assert_select ".resultado.error"
  end

  test "recargar la página después de probar un botón vuelve al catálogo" do
    ["/catalogo/definicion_invalida", "/catalogo/probar_send"].each do |ruta|
      get ruta

      assert_redirected_to "/catalogo"
    end
  end

  test "los datos de ejemplo del formulario son válidos para cada notificación" do
    Notification.catalogo.todas.each do |definicion|
      ejemplo = Demo::ProbarSend.datos_de_ejemplo(definicion.nombre)

      assert_equal definicion.datos.sort, ejemplo.keys.sort
      probar_send(notificacion: definicion.nombre, datos: ejemplo.to_json)
      assert_select ".resultado", text: /\ASolicitud #{UUID}\z/
    end
  end
end
