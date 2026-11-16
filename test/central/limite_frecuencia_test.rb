require "test_helper"

# R3: frecuencia máxima para lo no crítico. Máximo 3 notificaciones no críticas por
# persona y canal en 24 horas; lo que excede se retiene y queda anotado. Lo crítico
# está exento.
class LimiteFrecuenciaTest < ActiveSupport::TestCase
  setup do
    sembrar
    @ana = Usuario.find(1)
    @bruno = Usuario.find(2)
  end

  # Tres no críticas a la misma persona, despachando después de cada una.
  def tres_no_criticas(usuario)
    [
      enviar_recordatorio(usuario, curso: "Excel básico"),
      enviar_recordatorio(usuario, curso: "Excel avanzado"),
      enviar_encuesta(usuario, curso: "Excel básico")
    ].each { despachar }
  end

  test "19: la cuarta no crítica se retiene y la crítica pasa igual" do
    tres = tres_no_criticas(@ana)
    saludo = enviar_saludo(@ana)
    despachar
    certificado = enviar_certificado(@ana)
    despachar

    tres.each { |solicitud| assert_equal %w[recibida decision_enviar enviada], eventos(solicitud) }

    assert_equal %w[recibida retenida], eventos(saludo)
    retenida = recorrido(saludo).last
    assert_equal "limite_frecuencia", retenida.motivo
    assert_equal "email", retenida.canal
    assert_equal({ "llevaba" => 3, "limite" => 3 }, retenida.detalle)

    assert_equal %w[recibida decision_enviar enviada], eventos(certificado)
    assert_equal 0, Notification::Pendiente.count
    assert_equal 4, bandeja.size
  end

  test "19: lo retenido no ocupa cupo, y la siguiente no crítica también se retiene" do
    tres_no_criticas(@ana)
    enviar_saludo(@ana)
    despachar
    otra = enviar_encuesta(@ana, curso: "Tablas dinámicas")
    despachar

    assert_equal %w[recibida retenida], eventos(otra)
    assert_equal({ "llevaba" => 3, "limite" => 3 }, recorrido(otra).last.detalle)
  end

  test "20: el límite es por persona" do
    tres_no_criticas(@ana)
    de_bruno = enviar_saludo(@bruno, nombre: "Bruno")
    despachar

    assert_equal %w[recibida decision_enviar enviada], eventos(de_bruno)
  end

  test "32: la ventana del límite vence a las 24 horas" do
    tres_no_criticas(@ana)
    travel 24.hours + 1.minute
    cuarta = enviar_saludo(@ana)
    despachar

    assert_equal %w[recibida decision_enviar enviada], eventos(cuarta)
  end

  test "32: antes de las 24 horas el límite sigue vigente" do
    tres_no_criticas(@ana)
    travel 23.hours + 59.minutes
    cuarta = enviar_saludo(@ana)
    despachar

    assert_equal %w[recibida retenida], eventos(cuarta)
  end

  test "33: lo crítico no ocupa cupo" do
    (1..3).each do |numero|
      enviar_certificado(@ana, certificado_id: numero)
      despachar
    end
    no_critica = enviar_recordatorio(@ana)
    despachar

    assert_equal %w[recibida decision_enviar enviada], eventos(no_critica)
  end
end
