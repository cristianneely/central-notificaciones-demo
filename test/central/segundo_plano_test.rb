require "test_helper"

# El hilo en segundo plano mueve el despachador y los avisos del proveedor simulado.
# Aquí se prueba un paso ("tic") a mano; el hilo solo repite ese paso cada segundo.
class SegundoPlanoTest < ActiveSupport::TestCase
  # Un canal que revienta la primera vez que lo usan.
  class CanalQueFalla < Notification::Canales::Base
    def initialize
      @llamadas = 0
    end

    def nombre
      "inestable"
    end

    def contacto
      :correo
    end

    def adaptar(contenido)
      @llamadas += 1
      raise "error inesperado en el canal" if @llamadas == 1

      { texto: contenido[:titulo] }
    end

    def entregar_al_proveedor(mensaje, pendiente:, para:)
      Notification::Resultado.aceptado("inestable-1")
    end
  end

  setup { sembrar }

  test "un tic despacha los pendientes y hace llegar los avisos del proveedor" do
    freeze_time
    solicitud = enviar_certificado(Usuario.find(1))

    Notification::SegundoPlano.tic
    assert_equal %w[recibida decision_enviar enviada], eventos(solicitud)

    travel 2.seconds
    Notification::SegundoPlano.tic
    assert_equal "entregada", eventos(solicitud).last
  end

  test "un error inesperado con un pendiente no detiene el hilo ni a los demás pendientes" do
    Notification::Canales.registrar(CanalQueFalla.new)
    Notification::Politicas.por_defecto = { "critica" => ["inestable"] }
    con_error = enviar_certificado(Usuario.find(1), certificado_id: 1)
    travel 1.second
    sin_error = enviar_certificado(Usuario.find(2), certificado_id: 2)

    assert_nothing_raised { Notification::SegundoPlano.tic }

    assert_equal ["recibida"], eventos(con_error), "lo que alcanzó a anotar se deshace"
    assert_equal [con_error], Notification::Pendiente.pluck(:solicitud_id), "queda pendiente para la vuelta siguiente"
    assert_equal "enviada", eventos(sin_error).last

    Notification::SegundoPlano.tic
    assert_equal "enviada", eventos(con_error).last
  ensure
    Notification::Politicas.restablecer_por_defecto
    Notification::Canales.quitar("inestable")
  end
end
