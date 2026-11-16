require "test_helper"

# R7: agregar un canal no obliga a tocar ninguna definición. Un canal nuevo trae sus dos
# operaciones (adaptar y entregar a su proveedor) y se habilita en la política.
class CanalDePruebaTest < ActiveSupport::TestCase
  # Un canal falso que, en vez de hablar con un proveedor, guarda lo que le llega.
  class CanalFalso < Notification::Canales::Base
    attr_reader :recibidos

    def initialize
      @recibidos = []
    end

    def nombre
      "falso"
    end

    def adaptar(contenido)
      { texto: "#{contenido[:titulo]} / #{contenido[:cuerpo]}" }
    end

    def entregar_al_proveedor(mensaje, pendiente:, para:)
      @recibidos << mensaje.merge(para: para)
      Notification::Resultado.aceptado("falso-1")
    end
  end

  setup do
    sembrar
    @canal = CanalFalso.new
    Notification::Canales.registrar(@canal)
    Notification::Politicas.por_defecto = {
      "critica" => ["falso"], "informativa" => ["falso"], "opcional" => ["falso"]
    }
  end

  teardown do
    Notification::Politicas.restablecer_por_defecto
    Notification::Canales.quitar("falso")
  end

  test "29: el despachador entrega por un canal nuevo sin tocar ninguna definición" do
    definiciones_antes = Notification.catalogo.todas.dup

    solicitud = enviar_certificado(Usuario.find(1), curso: "Excel avanzado")
    despachar

    assert_equal [{ texto: "Tu certificado de Excel avanzado está listo / Felicitaciones, terminaste Excel avanzado.",
                    para: "ana.soto@ejemplo.test" }], @canal.recibidos
    assert_equal %w[recibida decision_enviar enviada], eventos(solicitud)
    assert_equal ["falso", "falso"], recorrido(solicitud).last(2).map(&:canal)
    assert_equal "falso-1", recorrido(solicitud).last.detalle["id_proveedor"]
    assert_equal 0, Notification::Pendiente.count
    assert_empty bandeja, "el canal email no participó"
    assert_equal definiciones_antes, Notification.catalogo.todas
  end

  test "29: al quitar el canal de prueba todo vuelve a salir por email" do
    Notification::Politicas.restablecer_por_defecto
    Notification::Canales.quitar("falso")

    assert_equal ["email"], Notification::Canales.nombres
    assert_equal ["email"], Notification::Politicas.canales_efectivos(empresa_id: 1, importancia: "critica")
  end
end
