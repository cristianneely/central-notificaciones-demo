require "test_helper"

# Políticas: por defecto según la criticidad (código) menos lo que el cliente apagó (R5).
# Lo crítico siempre tiene canal (R6).
class PoliticasTest < ActiveSupport::TestCase
  setup { sembrar }

  def assert_rechaza(mensaje, **politica)
    antes = Notification::PoliticaCliente.count
    error = assert_raises(Notification::PoliticaInvalida) do
      Notification::Politicas.guardar(**{ empresa_id: 1, criticidad: "opcional", canal: "email",
                                          habilitado: false }.merge(politica))
    end

    assert_equal mensaje, error.message
    assert_equal antes, Notification::PoliticaCliente.count
  end

  test "18: una política no puede dejar lo crítico sin canal" do
    assert_rechaza "Una política no puede dejar lo crítico sin canal", criticidad: "critica"
    assert_equal ["email"], Notification::Politicas.canales_efectivos(empresa_id: 1, criticidad: "critica")
  end

  test "18: criticidad desconocida" do
    assert_rechaza "criticidad desconocida: urgente", criticidad: "urgente"
  end

  test "18: canal desconocido" do
    assert_rechaza "canal desconocido: push", canal: "push"
  end

  test "18: apagar lo que no es crítico sí se guarda" do
    Notification::Politicas.guardar(empresa_id: 1, criticidad: "informativa", canal: "email", habilitado: false)

    assert_empty Notification::Politicas.canales_efectivos(empresa_id: 1, criticidad: "informativa")
    assert_equal ["email"], Notification::Politicas.canales_efectivos(empresa_id: 3, criticidad: "informativa")
  end

  test "18: volver a encender un canal lo devuelve a los canales efectivos" do
    Notification::Politicas.guardar(empresa_id: 2, criticidad: "opcional", canal: "email", habilitado: true)

    assert_equal ["email"], Notification::Politicas.canales_efectivos(empresa_id: 2, criticidad: "opcional")
    assert_equal 1, Notification::PoliticaCliente.count
  end

  test "canales efectivos: por defecto todo sale por email, menos lo que la empresa apagó" do
    assert_equal ["email"], Notification::Politicas.canales_efectivos(empresa_id: 1, criticidad: "opcional")
    assert_empty Notification::Politicas.canales_efectivos(empresa_id: 2, criticidad: "opcional")
    assert_equal ["email"], Notification::Politicas.canales_efectivos(empresa_id: 2, criticidad: "critica")
  end
end
