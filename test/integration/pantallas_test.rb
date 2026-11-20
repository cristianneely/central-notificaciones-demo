require "test_helper"

# Las cuatro pantallas de la demo. Ninguna lleva barra de aviso: que los datos son ficticios y
# que no sale ningún correo real lo dicen el inicio y la página Acerca.
class PantallasTest < ActionDispatch::IntegrationTest
  PANTALLAS = %w[/consola /catalogo /simulador /historial /acerca].freeze

  test "31: las pantallas cargan, sin barra de aviso" do
    sembrar

    PANTALLAS.each do |ruta|
      get ruta

      assert_response :ok, "#{ruta} debería cargar"
      assert_select ".aviso-demo", { count: 0 }, "#{ruta} no debería mostrar la barra de aviso"
    end
  end

  test "31: las pantallas cargan aunque la base no tenga datos semilla" do
    PANTALLAS.each do |ruta|
      get ruta

      assert_response :ok, "#{ruta} debería cargar sin datos"
    end
  end

  test "acerca explica que los datos son ficticios y que no sale ningún correo real" do
    get "/acerca"

    assert_includes css_select("main").text.squish,
                    "Todos los datos son ficticios y no sale ningún correo real"
  end

  test "65: acerca explica el contenido por piezas y lleva al simulador" do
    get "/acerca"

    assert_select "section#contenido-por-piezas h2", text: "Una definición, varios canales"
    assert_select "section#contenido-por-piezas a[href='/simulador']", text: "Simulador"
    assert_select "table.requisitos td", text: /\ASimulador: una definición dibujada por email, Slack, WhatsApp y SMS/
  end

  test "acerca declara las simplificaciones, los requisitos y la nota sobre send" do
    get "/acerca"

    assert_select "table.simplificaciones tbody tr", count: Demo::Declaraciones::SIMPLIFICACIONES.size
    assert_select "table.requisitos tbody tr", count: 14
    assert_includes response.body, "Proveedor simulado; no sale ningún correo"
    assert_includes response.body, "en producción se llamaría"
    assert_includes response.body, "El diseño llama <code>send</code> a la operación de envío"
    texto = css_select("main").text.squish
    assert_includes texto, "Para volver a los datos de ejemplo, usa \"Reiniciar demo\" al final de la consola."
    assert_no_match(/plan gratuito|despert|se duerme/i, texto)
    assert_select "table.requisitos td", text: "R11"
    assert_select ".bajada a[href='#{Demo::Declaraciones::PROPUESTA_URL}'][target=_blank]", text: "el diseño"
  end

  test "las declaraciones cubren los catorce requisitos" do
    assert_equal (1..14).map { |numero| "R#{numero}" }, Demo::Declaraciones::REQUISITOS.map(&:first)
    assert_operator Demo::Declaraciones::SIMPLIFICACIONES.size, :>=, 20
  end
end
