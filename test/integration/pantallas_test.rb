require "test_helper"

# Las cuatro pantallas de la demo. Todas llevan el aviso fijo de datos ficticios.
class PantallasTest < ActionDispatch::IntegrationTest
  AVISO = "Demo con datos ficticios. No sale ningún correo real."
  PANTALLAS = %w[/consola /catalogo /historial /acerca].freeze

  test "31: las cuatro pantallas cargan y muestran el aviso" do
    sembrar

    PANTALLAS.each do |ruta|
      get ruta

      assert_response :ok, "#{ruta} debería cargar"
      assert_includes response.body, AVISO, "#{ruta} debería mostrar el aviso"
      assert_select ".aviso-demo a[href='/acerca']"
    end
  end

  test "31: las pantallas cargan aunque la base no tenga datos semilla" do
    PANTALLAS.each do |ruta|
      get ruta

      assert_response :ok, "#{ruta} debería cargar sin datos"
      assert_includes response.body, AVISO
    end
  end

  test "acerca declara las simplificaciones, los requisitos y la nota sobre send" do
    get "/acerca"

    assert_select "table.simplificaciones tbody tr", count: Demo::Declaraciones::SIMPLIFICACIONES.size
    assert_select "table.requisitos tbody tr", count: 14
    assert_includes response.body, "Proveedor simulado; no sale ningún correo"
    assert_includes response.body, "en producción se llamaría"
    assert_includes response.body, "El diseño llama <code>send</code> a la operación de envío"
    assert_includes response.body, "puede tardar cerca de un minuto en despertar"
    assert_select "table.requisitos td", text: "R11"
    assert_select ".bajada a[href='#{Demo::Declaraciones::PROPUESTA_URL}'][target=_blank]", text: "el diseño"
  end

  test "las declaraciones cubren los catorce requisitos" do
    assert_equal (1..14).map { |numero| "R#{numero}" }, Demo::Declaraciones::REQUISITOS.map(&:first)
    assert_operator Demo::Declaraciones::SIMPLIFICACIONES.size, :>=, 20
  end
end
