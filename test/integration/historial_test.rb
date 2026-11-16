require "test_helper"

# R12: el historial se ve en una pantalla simple. Cada empresa ve solo lo suyo: la
# empresa es un filtro obligatorio.
class HistorialTest < ActionDispatch::IntegrationTest
  setup do
    sembrar
    @ana = Usuario.find(1)
    @bruno = Usuario.find(2)
    @ines = Usuario.find(9) # Minera Los Robles

    @de_ana = enviar_certificado(@ana, curso: "Excel avanzado")
    @de_bruno = enviar_recordatorio(@bruno)
    @de_ines = enviar_saludo(@ines, nombre: "Inés") # no enviada: política del cliente
    despachar
    avisar
  end

  def filas(**filtros)
    Notification::Historial.filas(**{ empresa_id: 1 }.merge(filtros))
  end

  test "30: filtrar por empresa muestra solo las filas de esa empresa" do
    assert_equal [@de_bruno, @de_ana], filas.map(&:solicitud_id)
    assert_equal [@de_ines], filas(empresa_id: 2).map(&:solicitud_id)
    assert_empty filas(empresa_id: 3)
  end

  test "30: incluye las no enviadas, con su motivo legible" do
    fila = filas(empresa_id: 2).sole

    assert_equal "No enviada: política del cliente", fila.estado
    assert_equal %w[recibida no_enviada], fila.recorrido.map(&:evento)
  end

  test "30: el recorrido de cada fila sale en orden" do
    fila = filas.find { |una| una.solicitud_id == @de_ana }

    assert_equal "Entregada", fila.estado
    assert_equal %w[recibida decision_enviar enviada entregada], fila.recorrido.map(&:evento)
    assert_equal ["certificado_emitido", "critica", @ana.id], [fila.notificacion, fila.importancia, fila.usuario_id]
  end

  test "30: filtrar por persona" do
    assert_equal [@de_ana], filas(usuario_id: @ana.id).map(&:solicitud_id)
  end

  test "30: filtrar por fechas, en hora de Chile" do
    hoy = Date.current

    assert_equal 2, filas(desde: hoy, hasta: hoy).size
    assert_empty filas(desde: hoy - 7, hasta: hoy - 1)
    assert_empty filas(desde: hoy + 1, hasta: hoy + 7)
  end

  test "30: una fila por solicitud y persona, de la más reciente a la más antigua, con tope" do
    solicitud = Notification.send "saludo_cumpleanos", empresa: 1, destinatarios: [@ana.id, @bruno.id],
                                                       datos: { nombre: "equipo", anio: 2026 }

    assert_equal [[solicitud, @bruno.id], [solicitud, @ana.id], [@de_bruno, @bruno.id], [@de_ana, @ana.id]],
                 filas.map { |fila| [fila.solicitud_id, fila.usuario_id] }
    assert_equal [[solicitud, @bruno.id], [solicitud, @ana.id]],
                 filas(limite: 2).map { |fila| [fila.solicitud_id, fila.usuario_id] }
  end

  test "30: el estado final de cada recorrido usa los textos de la pantalla" do
    estados = {
      "recibida" => "Pendiente",
      "decision_enviar" => "En espera del proveedor",
      "intento_fallido" => "En espera del proveedor",
      "enviada" => "Enviada, sin confirmación",
      "entregada" => "Entregada",
      "rebotada" => "Rebotada",
      "duplicada" => "Duplicada",
      "retenida" => "Retenida: límite de frecuencia"
    }
    estados.each do |evento, texto|
      assert_equal texto, Notification::Historial.estado(Notification::Auditoria.new(evento: evento))
    end

    con_motivo = ->(evento, motivo) { Notification::Auditoria.new(evento: evento, motivo: motivo) }
    assert_equal "No enviada: sin contacto",
                 Notification::Historial.estado(con_motivo.call("no_enviada", "sin_contacto"))
    assert_equal "Falló: el proveedor rechazó el correo",
                 Notification::Historial.estado(con_motivo.call("fallo_definitivo", "rechazado_por_proveedor"))
    assert_equal "proveedor no disponible", Notification::Historial.motivo_legible("proveedor_no_disponible")
    assert_equal "límite de frecuencia", Notification::Historial.motivo_legible("limite_frecuencia")
  end

  test "30: la pantalla muestra por defecto la primera empresa y los últimos 7 días" do
    get "/historial"

    assert_response :ok
    assert_select "select[name=empresa_id] option[selected]", text: "Andes Capacitación"
    assert_select "input[name=desde][value='#{Date.current - 7}']"
    assert_select "input[name=hasta][value='#{Date.current}']"
    assert_select ".fila-historial", count: 2
    assert_includes response.body, "Entregada"
    assert_includes response.body, "Ana Soto"
    assert_not_includes response.body, "Inés Castro"
  end

  test "30: la pantalla filtra por empresa y persona" do
    get "/historial", params: { empresa_id: 2 }
    assert_select ".fila-historial", count: 1
    assert_includes response.body, "No enviada: política del cliente"

    get "/historial", params: { empresa_id: 1, usuario_id: @ana.id }
    assert_select ".fila-historial", count: 1
  end

  test "30: filtros mal escritos no rompen la pantalla" do
    get "/historial", params: { empresa_id: 999, usuario_id: "abc", desde: "xx", hasta: "32-13-2026" }
    assert_response :ok
    assert_select "select[name=empresa_id] option[selected]", text: "Andes Capacitación"

    get "/historial", params: { desde: Date.current.to_s, hasta: (Date.current - 3).to_s }
    assert_response :ok
    assert_select ".fila-historial", count: 0
  end
end
