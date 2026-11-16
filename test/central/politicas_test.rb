require "test_helper"

# Políticas: por defecto según la importancia (código) menos lo que el cliente apagó (R5).
# Lo crítico siempre tiene canal (R6).
class PoliticasTest < ActiveSupport::TestCase
  setup { sembrar }

  def assert_rechaza(mensaje, **politica)
    antes = Notification::PoliticaCliente.count
    error = assert_raises(Notification::PoliticaInvalida) do
      Notification::Politicas.guardar(**{ empresa_id: 1, importancia: "opcional", canal: "email",
                                          habilitado: false }.merge(politica))
    end

    assert_equal mensaje, error.message
    assert_equal antes, Notification::PoliticaCliente.count
  end

  test "18: una política no puede dejar lo crítico sin canal" do
    assert_rechaza "Una política no puede dejar lo crítico sin canal", importancia: "critica"
    assert_equal ["email"], Notification::Politicas.canales_efectivos(empresa_id: 1, importancia: "critica")
  end

  test "18: importancia desconocida" do
    assert_rechaza "importancia desconocida: urgente", importancia: "urgente"
  end

  test "18: canal desconocido" do
    assert_rechaza "canal desconocido: sms", canal: "sms"
  end

  test "18: apagar lo que no es crítico sí se guarda" do
    Notification::Politicas.guardar(empresa_id: 1, importancia: "informativa", canal: "email", habilitado: false)

    assert_empty Notification::Politicas.canales_efectivos(empresa_id: 1, importancia: "informativa")
    assert_equal ["email"], Notification::Politicas.canales_efectivos(empresa_id: 3, importancia: "informativa")
  end

  test "18: volver a encender un canal lo devuelve a los canales efectivos" do
    Notification::Politicas.guardar(empresa_id: 2, importancia: "opcional", canal: "email", habilitado: true)

    assert_equal ["email"], Notification::Politicas.canales_efectivos(empresa_id: 2, importancia: "opcional")
    assert_equal 1, Notification::PoliticaCliente.count
  end

  test "canales efectivos: por defecto todo sale por email, menos lo que la empresa apagó" do
    assert_equal ["email"], Notification::Politicas.canales_efectivos(empresa_id: 1, importancia: "opcional")
    assert_empty Notification::Politicas.canales_efectivos(empresa_id: 2, importancia: "opcional")
    assert_equal ["email"], Notification::Politicas.canales_efectivos(empresa_id: 2, importancia: "critica")
  end
end
