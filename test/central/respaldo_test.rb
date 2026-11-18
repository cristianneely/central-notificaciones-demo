require "test_helper"

# R6: lo crítico tiene respaldo. Si el primer canal rechaza el envío en forma definitiva,
# lo crítico se intenta por el canal siguiente de la política. La demo tiene un solo canal
# (email), así que aquí se prueba con dos canales de prueba.
class RespaldoTest < ActiveSupport::TestCase
  # Un canal falso que responde lo que la prueba le diga y guarda lo que le llega.
  class CanalFalso < Notification::Canales::Base
    attr_reader :nombre, :recibidos
    attr_accessor :respuesta, :contacto

    def initialize(nombre, respuesta)
      @nombre = nombre
      @respuesta = respuesta
      @contacto = :correo
      @recibidos = []
    end

    def adaptar(contenido)
      { texto: contenido[:titulo] }
    end

    def entregar_al_proveedor(mensaje, pendiente:, para:)
      @recibidos << para
      case respuesta
      when :acepta then Notification::Resultado.aceptado("#{nombre}-#{@recibidos.size}")
      when :rechaza then Notification::Resultado.rechazado("rechazado por #{nombre}")
      else Notification::Resultado.sin_respuesta
      end
    end
  end

  setup do
    sembrar
    freeze_time
    @ana = Usuario.find(1)
    @primero = CanalFalso.new("primero", :rechaza)
    @segundo = CanalFalso.new("segundo", :acepta)
    [@primero, @segundo].each { |canal| Notification::Canales.registrar(canal) }
    usar_politica %w[primero segundo]
  end

  teardown do
    Notification::Politicas.restablecer_por_defecto
    %w[primero segundo].each { |nombre| Notification::Canales.quitar(nombre) }
  end

  def usar_politica(canales)
    Notification::Politicas.por_defecto = {
      "critica" => canales, "informativa" => canales, "opcional" => canales
    }
  end

  def canales_del_recorrido(solicitud)
    recorrido(solicitud).drop(1).map(&:canal)
  end

  test "42: lo crítico rechazado por el primer canal sale por el siguiente" do
    solicitud = enviar_certificado(@ana)
    despachar

    assert_equal %w[recibida decision_enviar fallo_definitivo decision_enviar enviada], eventos(solicitud)
    assert_equal %w[primero primero segundo segundo], canales_del_recorrido(solicitud)
    assert_equal ["ana.soto@ejemplo.test"], @segundo.recibidos
    assert_equal "ana.soto@ejemplo.test", recorrido(solicitud).last.detalle["para"]
    assert_equal 0, Notification::Pendiente.count
  end

  test "42: lo no crítico rechazado no usa respaldo" do
    solicitud = enviar_recordatorio(@ana)
    despachar

    assert_equal %w[recibida decision_enviar fallo_definitivo], eventos(solicitud)
    assert_empty @segundo.recibidos
    assert_equal 0, Notification::Pendiente.count
  end

  test "42: si el respaldo también rechaza, termina en fallo definitivo" do
    @segundo.respuesta = :rechaza
    solicitud = enviar_certificado(@ana)
    despachar

    assert_equal %w[recibida decision_enviar fallo_definitivo decision_enviar fallo_definitivo], eventos(solicitud)
    assert_equal %w[primero primero segundo segundo], canales_del_recorrido(solicitud)
    assert_equal 0, Notification::Pendiente.count
  end

  test "42: si la empresa apagó el canal de respaldo, no hay respaldo" do
    Notification::Politicas.guardar(empresa_id: 1, criticidad: "critica", canal: "segundo", habilitado: false)
    solicitud = enviar_certificado(@ana)
    despachar

    assert_equal %w[recibida decision_enviar fallo_definitivo], eventos(solicitud)
    assert_empty @segundo.recibidos
  end

  test "42: si a la persona le falta el dato del canal de respaldo, queda sin contacto" do
    @segundo.contacto = :telefono
    solicitud = enviar_certificado(@ana)
    despachar

    assert_equal %w[recibida decision_enviar fallo_definitivo no_enviada], eventos(solicitud)
    ultima = recorrido(solicitud).last
    assert_equal ["sin_contacto", "segundo"], [ultima.motivo, ultima.canal]
    assert_empty @segundo.recibidos
    assert_equal 0, Notification::Pendiente.count
  end

  test "42: si el respaldo no responde, el pendiente espera y reanuda por el respaldo" do
    @segundo.respuesta = :no_responde
    solicitud = enviar_certificado(@ana)
    despachar

    assert_equal %w[recibida decision_enviar fallo_definitivo decision_enviar intento_fallido], eventos(solicitud)
    assert_equal "segundo", recorrido(solicitud).last.canal
    assert_equal 1, Notification::Pendiente.count

    @segundo.respuesta = :acepta
    travel 5.seconds
    despachar

    assert_equal %w[recibida decision_enviar fallo_definitivo decision_enviar intento_fallido enviada],
                 eventos(solicitud)
    assert_equal "segundo", recorrido(solicitud).last.canal
    assert_equal 1, @primero.recibidos.size, "el primer canal no se vuelve a intentar"
    assert_equal 0, Notification::Pendiente.count
  end

  test "42: un rebote informado después no activa el respaldo" do
    usar_politica %w[email segundo]
    solicitud = enviar_certificado(persona("(rebota)", empresa_id: 1))
    despachar
    avisar

    assert_equal %w[recibida decision_enviar enviada rebotada], eventos(solicitud)
    assert_empty @segundo.recibidos
  end
end
