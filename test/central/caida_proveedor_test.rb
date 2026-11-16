require "test_helper"

# R14: nada se pierde si el proveedor falla. Los reintentos son por canal: mientras el
# proveedor no responde, la central deja de tomar pendientes, prueba de nuevo tras
# esperas crecientes (5, 10, 20 s) y, cuando vuelve, salen todos con lo crítico primero.
class CaidaProveedorTest < ActiveSupport::TestCase
  Simulado = Notification::Proveedores::Simulado

  setup do
    sembrar
    freeze_time
    Simulado.apagar
    # Dos informativas y, después, dos críticas.
    @informativas = [enviar_recordatorio(Usuario.find(1)), enviar_recordatorio(Usuario.find(2))]
    @criticas = [enviar_certificado(Usuario.find(3), certificado_id: 1),
                 enviar_certificado(Usuario.find(4), certificado_id: 2)]
  end

  def canal
    Notification::EstadoCanal.para("email")
  end

  def intentos_fallidos
    Notification::Auditoria.where(evento: "intento_fallido").order(:id).to_a
  end

  test "21: con el proveedor caído se intenta una vez, con una crítica, y nada se pierde" do
    despachar

    intento = intentos_fallidos.sole
    assert_equal @criticas.first, intento.solicitud_id
    assert_equal "certificado_emitido", intento.notificacion
    assert_equal "proveedor_no_disponible", intento.motivo
    assert_equal "email", intento.canal
    assert_equal({ "falla_consecutiva" => 1 }, intento.detalle)

    assert_equal 4, Notification::Pendiente.count
    assert_equal 1, canal.fallas_consecutivas
    assert_equal Time.current + 5.seconds, canal.proximo_intento_en
    assert_empty bandeja
    assert_equal %w[recibida decision_enviar intento_fallido], eventos(@criticas.first)
    (@informativas + [@criticas.last]).each { |solicitud| assert_equal ["recibida"], eventos(solicitud) }
  end

  test "22: las esperas crecen 5, 10 y 20 segundos, y antes de tiempo no se intenta" do
    despachar
    assert_equal [1, 5.seconds.from_now], [canal.fallas_consecutivas, canal.proximo_intento_en]

    travel 4.seconds
    assert_equal 0, despachar, "antes de tiempo no se toma ningún pendiente"
    assert_equal 1, intentos_fallidos.size

    travel 1.second
    despachar
    assert_equal [2, 10.seconds.from_now], [canal.fallas_consecutivas, canal.proximo_intento_en]

    travel 10.seconds
    despachar
    assert_equal [3, 20.seconds.from_now], [canal.fallas_consecutivas, canal.proximo_intento_en]

    travel 20.seconds
    despachar
    assert_equal [4, 20.seconds.from_now], [canal.fallas_consecutivas, canal.proximo_intento_en]

    assert_equal [1, 2, 3, 4], intentos_fallidos.map { |fila| fila.detalle["falla_consecutiva"] }
    assert_equal [@criticas.first], intentos_fallidos.map(&:solicitud_id).uniq, "siempre prueba con la más crítica"
    assert_equal 4, Notification::Pendiente.count
  end

  test "23: al volver el proveedor salen todos, lo crítico primero, con una sola decisión cada uno" do
    despachar
    Simulado.encender

    assert_equal 0, despachar, "encender no avisa a la central: espera su próximo intento"
    assert_empty bandeja

    travel 5.seconds
    despachar

    enviadas = Notification::Auditoria.where(evento: "enviada").order(:id).pluck(:solicitud_id)
    assert_equal @criticas + @informativas, enviadas
    assert_equal 0, Notification::Pendiente.count
    assert_equal 0, canal.fallas_consecutivas
    assert_nil canal.proximo_intento_en
    assert_equal 4, bandeja.size

    (@criticas + @informativas).each do |solicitud|
      assert_equal 1, eventos(solicitud).count("decision_enviar")
    end
    assert_equal %w[recibida decision_enviar intento_fallido enviada], eventos(@criticas.first)
  end

  test "23: un rechazo puntual también cuenta como que el proveedor respondió" do
    despachar
    Simulado.encender
    invalido = enviar_certificado(persona("(correo inválido)"), certificado_id: 3)
    travel 5.seconds
    despachar

    assert_equal "fallo_definitivo", eventos(invalido).last
    assert_equal 0, canal.fallas_consecutivas
    assert_equal 0, Notification::Pendiente.count
  end

  test "el interruptor del proveedor simulado parte encendido y se puede apagar y encender" do
    Simulado.encender
    assert Simulado.encendido?
    Simulado.apagar
    assert_not Simulado.encendido?
    Simulado.apagar
    assert_not Simulado.encendido?
  end
end
