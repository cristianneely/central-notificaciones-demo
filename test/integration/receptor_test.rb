require "test_helper"

# El receptor: la puerta por donde el proveedor avisa el estado final de un correo.
class ReceptorTest < ActionDispatch::IntegrationTest
  setup do
    sembrar
    @solicitud = enviar_certificado(Usuario.find(1))
    despachar
    @aviso = { solicitud_id: @solicitud, usuario_id: 1, id_proveedor: bandeja.sole.id_proveedor,
               estado: "entregado" }
  end

  def avisar_por_http(aviso)
    post "/receptor/proveedor", params: aviso, as: :json
  end

  test "26: un aviso válido se anota" do
    avisar_por_http(@aviso)

    assert_response :ok
    assert_equal({ "ok" => true }, response.parsed_body)
    assert_equal "entregada", eventos(@solicitud).last
    assert_equal "email", recorrido(@solicitud).last.canal
  end

  test "26: un rebote se anota como rebotada" do
    avisar_por_http(@aviso.merge(estado: "rebotado"))

    assert_response :ok
    assert_equal "rebotada", eventos(@solicitud).last
  end

  test "26: un aviso repetido responde bien y no anota de nuevo" do
    avisar_por_http(@aviso)
    avisar_por_http(@aviso.merge(estado: "rebotado"))

    assert_response :ok
    assert_equal %w[recibida decision_enviar enviada entregada], eventos(@solicitud)
  end

  test "26: un aviso de un envío que no existe" do
    avisar_por_http(@aviso.merge(id_proveedor: "sim-999999"))

    assert_response :not_found
    assert_equal({ "error" => "no existe un envío con esos datos" }, response.parsed_body)
    assert_equal %w[recibida decision_enviar enviada], eventos(@solicitud)
  end

  test "26: un estado que no es entregado ni rebotado" do
    avisar_por_http(@aviso.merge(estado: "abierto"))

    assert_response :unprocessable_content
    assert_equal({ "error" => "estado debe ser entregado o rebotado" }, response.parsed_body)
  end

  test "26: falta un campo" do
    avisar_por_http(@aviso.except(:usuario_id))

    assert_response :unprocessable_content
    assert_equal({ "error" => "falta usuario_id" }, response.parsed_body)
  end

  test "26: un cuerpo que no es JSON no rompe el receptor" do
    post "/receptor/proveedor", params: "{esto no es json", headers: { "Content-Type" => "application/json" }

    assert_response :bad_request
    assert_equal({ "error" => "JSON inválido" }, response.parsed_body)
  end
end
