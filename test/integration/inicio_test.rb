require "test_helper"

# La página de inicio: lo primero que ve quien llega desde un link. Dice qué es la demo,
# dónde está la propuesta, dónde está el código y qué mirar.
class InicioTest < ActionDispatch::IntegrationTest
  PROPUESTA = Demo::Declaraciones::PROPUESTA_URL
  CODIGO = Demo::Declaraciones::CODIGO_URL
  PANTALLAS = %w[/ /consola /catalogo /historial /acerca].freeze

  test "el inicio carga con su título, su bajada, el ejemplo y el recorrido" do
    sembrar
    get "/"

    assert_response :ok
    assert_select "h1", text: "Central de notificaciones"
    texto = css_select("main").text.squish
    assert_includes texto, "Implementación de las partes 1 y 2 de la propuesta: definir una notificación, " \
                           "enviarla, evitar el spam y ver el historial. Usa datos ficticios y un proveedor " \
                           "de correo simulado: no sale ningún correo real."
    assert_includes texto, "El ejemplo es una plataforma de capacitación: la notificación principal es el " \
                           "certificado de un curso. También están definidos un recordatorio, una encuesta y " \
                           "un saludo de cumpleaños."
    assert_includes texto, "La app está en un plan gratuito y vuelve a los datos de ejemplo cuando se duerme. " \
                           "El detalle de lo que se simplificó está en Acerca."
    assert_select "h2", text: "Recorrido de 2 minutos"
    assert_select "ol.recorrido-corto li", count: 4
    assert_select "main a[href='/acerca']", text: "Acerca"
  end

  test "el inicio tiene los tres accesos" do
    get "/"

    assert_select ".accesos a[href='#{PROPUESTA}'][target=_blank]", text: "Leer la propuesta"
    assert_select ".accesos a[href='/consola']", text: "Abrir la demo"
    assert_select ".accesos a[href='#{CODIGO}'][target=_blank]", text: "Ver el código"
  end

  test "los pasos del recorrido llevan a su pantalla" do
    get "/"

    assert_select "ol.recorrido-corto li a[href='/consola']", count: 3
    assert_select "ol.recorrido-corto li a[href='/historial?empresa_id=3']", text: "Historial de Clínica Austral"
  end

  test "la raíz ya no es la consola" do
    sembrar
    get "/"

    assert_not_includes response.body, "1. Acciones de negocio"
  end

  test "el inicio carga aunque la base no tenga datos semilla" do
    get "/"

    assert_response :ok
    assert_includes response.body, "Demo con datos ficticios. No sale ningún correo real."
  end

  test "el menú está en las cinco pantallas, con la propuesta y el código en pestaña nueva" do
    sembrar

    PANTALLAS.each do |ruta|
      get ruta

      { "Inicio" => "/", "Consola" => "/consola", "Catálogo" => "/catalogo",
        "Historial" => "/historial", "Acerca" => "/acerca" }.each do |texto, destino|
        assert_select "nav.menu a[href='#{destino}']", { text: texto }, "#{ruta}: falta #{texto} en el menú"
      end
      assert_select "nav.menu a[href='#{PROPUESTA}'][target=_blank]", text: "Propuesta"
      assert_select "nav.menu a[href='#{CODIGO}'][target=_blank]", text: "Código"
    end
  end

  test "todo link que abre pestaña nueva lleva rel noopener" do
    sembrar

    %w[/ /consola].each do |ruta|
      get ruta

      enlaces = css_select("a[target=_blank]")
      assert enlaces.any?, "#{ruta} debería tener links externos"
      enlaces.each do |enlace|
        assert_includes enlace["rel"].to_s.split, "noopener", "#{ruta}: #{enlace["href"]} sin noopener"
      end
    end
  end
end
