require "test_helper"

# La página de inicio: lo primero que ve quien llega desde un link. Dice qué es la demo,
# dónde está la propuesta, dónde está el código y qué mirar.
class InicioTest < ActionDispatch::IntegrationTest
  PROPUESTA = Demo::Declaraciones::PROPUESTA_URL
  CODIGO = Demo::Declaraciones::CODIGO_URL
  PANTALLAS = %w[/ /consola /catalogo /historial /acerca].freeze

  test "el inicio tiene solo el título, la autoría, la frase, los tres accesos y el pie" do
    sembrar
    get "/"

    assert_response :ok
    assert_select "h1", text: "Propuesta técnica: central de notificaciones"
    assert_select ".inicio .autoria", text: "Cristián Neely, noviembre de 2026"
    texto = css_select("main").text.squish
    assert_includes texto, "Implementación de las partes 1 y 2 de la propuesta, con datos ficticios. " \
                           "No sale ningún correo real."
    assert_includes texto, "La demo corre en un plan gratuito y vuelve a los datos de ejemplo cuando se " \
                           "duerme. Lo que simplifica respecto de la propuesta está en Acerca."
    assert_select ".inicio .pie a[href='/acerca']", text: "Acerca"
  end

  test "el inicio tiene los tres accesos como links de texto, con su descripción" do
    get "/"

    assert_select ".accesos li", count: 3
    assert_select ".accesos li:nth-child(1) a[href='#{PROPUESTA}'][target=_blank]", text: "Leer la propuesta"
    assert_select ".accesos li:nth-child(1) .descripcion", text: "Requisitos, solución y riesgos."
    assert_select ".accesos li:nth-child(2) a[href='/consola']", text: "Abrir la demo"
    assert_select ".accesos li:nth-child(2) .descripcion", text: "Definir, enviar y seguir una notificación."
    assert_select ".accesos li:nth-child(3) a[href='#{CODIGO}'][target=_blank]", text: "Ver el código"
    assert_select ".accesos li:nth-child(3) .descripcion", count: 0
  end

  test "el inicio ya no tiene el recorrido, el ejemplo, tarjetas ni botones" do
    get "/"

    assert_not_includes response.body, "Recorrido de 2 minutos"
    assert_not_includes response.body, "plataforma de capacitación"
    assert_select "main .tarjeta", count: 0
    assert_select "main button", count: 0
  end

  test "la raíz ya no es la consola" do
    sembrar
    get "/"

    assert_not_includes response.body, "1. Acciones de negocio"
  end

  test "el inicio no muestra el aviso amarillo; las demás pantallas sí" do
    get "/"
    assert_response :ok
    assert_select ".aviso-demo", count: 0

    get "/acerca"
    assert_select ".aviso-demo", count: 1
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
