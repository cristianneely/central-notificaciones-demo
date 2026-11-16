require "test_helper"

# Las dos puertas de la demo: la pantalla (web) y la API. Las dos llaman a la misma
# acción de negocio, así que notifican igual (R9).
class PuertasTest < ActionDispatch::IntegrationTest
  setup { sembrar }

  def emitir_por_api(cuerpo)
    post "/api/certificados", params: cuerpo, as: :json
  end

  def assert_nada_guardado
    assert_equal 0, Certificado.count
    assert_equal [0, 0, 0], conteos_de_send
  end

  def assert_api_rechaza(mensaje, cuerpo)
    emitir_por_api(cuerpo)

    assert_response :unprocessable_content
    assert_equal({ "error" => mensaje }, response.parsed_body)
    assert_nada_guardado
  end

  test "24: emitir por la pantalla y por la API notifica igual" do
    pedido = { empresa_id: 1, usuario_id: 1, curso: "Excel avanzado" }

    post "/acciones/emitir_certificado", params: pedido
    assert_redirected_to "/?curso=Excel+avanzado&empresa_id=1&usuario_id=1"

    emitir_por_api(pedido)
    assert_response :created
    assert_equal Certificado.last.id, response.parsed_body["certificado_id"]
    assert_match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/, response.parsed_body["solicitud_id"])

    despachar
    avisar

    assert_equal 2, Certificado.count
    por_web, por_api = Notification::Auditoria.where(evento: "recibida").order(:id).to_a
    assert_equal "web", por_web.detalle["origen"]
    assert_equal "api", por_api.detalle["origen"]
    assert_equal response.parsed_body["solicitud_id"], por_api.solicitud_id
    assert_equal %w[recibida decision_enviar enviada entregada], eventos(por_web.solicitud_id)
    assert_equal eventos(por_web.solicitud_id), eventos(por_api.solicitud_id)
  end

  test "24: la API no acepta los interruptores de demo" do
    emitir_por_api(empresa_id: 1, usuario_id: 1, curso: "Excel avanzado",
                   fallar_a_la_mitad: "1", llamar_dos_veces: "1")

    assert_response :created
    assert_equal 1, Certificado.count
    assert_equal ["recibida"], Notification::Auditoria.pluck(:evento)
  end

  test "25: API sin curso" do
    assert_api_rechaza "falta curso", empresa_id: 1, usuario_id: 1
  end

  test "25: API con una persona de otra empresa" do
    assert_api_rechaza "la persona no pertenece a la empresa", empresa_id: 1, usuario_id: 9, curso: "Excel avanzado"
  end

  test "25: API con JSON roto" do
    post "/api/certificados", params: '{"empresa_id":', headers: { "Content-Type" => "application/json" }

    assert_response :bad_request
    assert_equal({ "error" => "JSON inválido" }, response.parsed_body)
    assert_nada_guardado
  end

  test "25: los demás mensajes de la API" do
    assert_api_rechaza "falta empresa_id", usuario_id: 1, curso: "Excel avanzado"
    assert_api_rechaza "falta usuario_id", empresa_id: 1, curso: "Excel avanzado"
    assert_api_rechaza "empresa desconocida", empresa_id: 999, usuario_id: 1, curso: "Excel avanzado"
    assert_api_rechaza "curso demasiado largo", empresa_id: 1, usuario_id: 1, curso: "x" * 101
  end

  test "25: API con tipos equivocados responde con sus mensajes, nunca con un error 500" do
    assert_api_rechaza "empresa desconocida", empresa_id: "abc", usuario_id: 1, curso: "Excel avanzado"
    assert_api_rechaza "la persona no pertenece a la empresa", empresa_id: 1, usuario_id: [1], curso: "Excel avanzado"
    assert_api_rechaza "falta curso", empresa_id: 1, usuario_id: 1, curso: "   "

    emitir_por_api(empresa_id: 1, usuario_id: 1, curso: 123)
    assert_response :created
    assert_equal "123", Certificado.sole.curso
  end

  test "pantalla: un pedido manipulado vuelve a la consola con el mismo mensaje que la API" do
    post "/acciones/emitir_certificado", params: { empresa_id: 1, usuario_id: 9, curso: "Excel avanzado" }
    assert_response :redirect
    assert_equal "la persona no pertenece a la empresa", flash[:error]

    post "/acciones/emitir_certificado", params: { empresa_id: 1, usuario_id: 1, curso: "" }
    assert_response :redirect
    assert_equal "falta curso", flash[:error]

    assert_nada_guardado
  end

  test "pantalla: la casilla falla a la mitad deshace todo y lo informa" do
    post "/acciones/emitir_certificado",
         params: { empresa_id: 1, usuario_id: 1, curso: "Excel avanzado", fallar_a_la_mitad: "1" }

    assert_response :redirect
    assert_equal "La acción falló a la mitad: no se guardó el certificado ni la notificación.", flash[:error]
    assert_nada_guardado
  end

  test "pantalla: las otras tres acciones piden su notificación con origen web" do
    pedido = { empresa_id: 1, usuario_id: 1, curso: "Excel básico" }
    post "/acciones/recordatorio", params: pedido
    post "/acciones/encuesta", params: pedido
    post "/acciones/cumpleanos", params: pedido

    assert_response :redirect
    assert_match(/\AAcción ejecutada\. Solicitud \h{8}\.\z/, flash[:resultado])
    assert_equal %w[recordatorio_curso encuesta_satisfaccion saludo_cumpleanos],
                 Notification::Pendiente.order(:id).pluck(:notificacion)
    assert_equal ["web"], Notification::Auditoria.all.map { |fila| fila.detalle["origen"] }.uniq
  end

  test "pantalla: un pedido sin datos a las otras acciones no da error 500" do
    post "/acciones/recordatorio", params: { empresa_id: "abc", usuario_id: "", curso: "" }

    assert_response :redirect
    assert_equal "empresa desconocida: 0", flash[:error]
    assert_nada_guardado
  end
end
