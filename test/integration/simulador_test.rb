require "test_helper"

# El simulador: una definición dibujada por los cuatro canales de la tabla de la sección
# 2.1.5. Usa Contenido.rellenar y el adaptar de cada canal, sin pasar por send(), y no
# escribe nada en la base.
class SimuladorTest < ActionDispatch::IntegrationTest
  NOTIFICACIONES = %w[solicitud_vacaciones saludo_cumpleanos certificado_emitido].freeze

  setup { sembrar }

  def conteos
    [Notification::ClaveUnica.count, Notification::Pendiente.count, Notification::Auditoria.count,
     Notification::Proveedores::CorreoSimulado.count]
  end

  test "58: cada una de las tres notificaciones se ve en los cinco canales" do
    NOTIFICACIONES.each do |nombre|
      get "/simulador", params: { notificacion: nombre }

      assert_response :ok
      assert_select ".canal", count: 5
      assert_select ".canal-email .asunto-bandeja", text: Demo::Simulador.simular(nombre, {})[:canales].first[:mensaje][:asunto]
      assert_select ".canal-email iframe[srcdoc]"
      assert_select ".canal-slack .slack-encabezado"
      assert_select ".canal-whatsapp .burbuja-whatsapp"
      assert_select ".canal-sms .largo-sms", text: /\A\d+ de 160 caracteres\z/
      assert_select ".canal-push .push-notificacion .push-titulo"
    end
  end

  test "58: simular devuelve la definición, el código y los cuatro canales" do
    simulacion = Demo::Simulador.simular("solicitud_vacaciones", {})

    assert_equal "solicitud_vacaciones", simulacion[:definicion].nombre
    assert_equal %w[email slack whatsapp sms push], simulacion[:canales].map { |canal| canal[:nombre] }
    assert_includes simulacion[:codigo], "class SolicitudVacaciones < Notification"
    assert_equal "Ana Soto", simulacion[:datos][:solicitante]
  end

  test "59: el simulador no escribe nada en la base" do
    enviar_certificado(Usuario.find(1))
    despachar
    antes = conteos

    NOTIFICACIONES.each { |nombre| get "/simulador", params: { notificacion: nombre, datos: { curso: "Otro" } } }

    assert_equal antes, conteos
  end

  test "60: un dato editado aparece en los cuatro canales" do
    get "/simulador", params: { notificacion: "certificado_emitido", datos: { curso: "Power BI" } }

    assert_select ".canal-email .asunto-bandeja", text: "Tu certificado de Power BI está listo"
    assert_select ".canal-slack .slack-encabezado", text: "Tu certificado de Power BI está listo"
    assert_select ".canal-whatsapp .burbuja-whatsapp", text: /Power BI/
    assert_select ".canal-sms .burbuja-sms", text: /Terminaste Power BI\./
    assert_select ".canal-push .push-titulo", text: "Tu certificado de Power BI está listo"
    assert_select "input[name='datos[curso]'][value='Power BI']"
  end

  test "61: bajo cada canal se ve qué se degradó" do
    get "/simulador", params: { notificacion: "solicitud_vacaciones" }

    assert_select ".canal-sms .notas li", text: "Lista: se omite"
    assert_select ".canal-push .notas li", text: "Lista: se omite"
    assert_select ".canal-push .push-notificacion img[src='/vacaciones.svg']"
    assert_select ".canal-whatsapp .notas li", text: "Botón: pasa a link (sin plantilla aprobada)"
    assert_select ".canal-whatsapp .boton-plantilla", count: 0
    assert_select ".canal-email .notas", text: /Sin degradación/

    get "/simulador", params: { notificacion: "certificado_emitido" }
    assert_select ".canal-whatsapp .boton-plantilla", text: "Descargar"

    get "/simulador", params: { notificacion: "saludo_cumpleanos" }
    assert_select ".canal-sms .notas li", text: "Imagen: se omite"
    assert_select ".canal-whatsapp .plantilla-estado", count: 0 # sin botón, la plantilla no importa
    assert_select ".canal-whatsapp .burbuja-whatsapp img[alt='Tarjeta de saludo de cumpleaños']"
  end

  test "62: una notificación que no existe o datos mal formados no rompen la pantalla" do
    get "/simulador", params: { notificacion: "no_existe" }
    assert_response :ok
    assert_select "select[name=notificacion] option[selected]", text: "solicitud_vacaciones"

    get "/simulador?notificacion=certificado_emitido&datos=hola"
    assert_response :ok

    get "/simulador", params: { notificacion: "certificado_emitido", datos: { curso: { a: 1 }, otro: "x" } }
    assert_response :ok
    assert_select ".canal-email .asunto-bandeja", text: "Tu certificado de Excel avanzado está listo"
  end

  test "58: el correo abierto puede cargar las imágenes de la demo, pero no correr scripts" do
    get "/simulador", params: { notificacion: "saludo_cumpleanos" }

    # Con un sandbox vacío el iframe queda con origen nulo y el navegador no le deja pedir
    # la imagen a la demo. allow-same-origin la deja pasar; sin allow-scripts, nada corre.
    iframe = css_select(".canal-email iframe").first
    assert_equal "allow-same-origin", iframe["sandbox"]
    assert_includes iframe["srcdoc"], %(<img src="/tarjeta-cumpleanos.svg")
  end

  test "63: la pantalla muestra la definición tal como se escribe y dice que no guarda nada" do
    get "/simulador", params: { notificacion: "certificado_emitido" }

    assert_select ".definicion-codigo", text: /contenido do/
    assert_select ".aviso-simulador", text: /no escribe nada/
  end

  test "64: el mensaje crudo de cada proveedor está en la página" do
    get "/simulador", params: { notificacion: "certificado_emitido" }

    assert_select "#ver-crudo[type=checkbox]"
    assert_select ".canal-email .crudo", text: /<h1>Tu certificado de Excel avanzado está listo<\/h1>/
    assert_select ".canal-slack .crudo", text: /"type": "header"/
    assert_select ".canal-whatsapp .crudo", text: /"plantilla": "certificado_emitido"/
    assert_select ".canal-push .crudo", text: /"link": "https:\/\/ejemplo\.test\/certificados\/1001"/
    assert_select ".canal-sms .crudo", text: %r{Terminaste Excel avanzado\. Descarga tu certificado\. https://nj\.test/}
  end

  test "el menú lleva al simulador" do
    get "/consola"

    assert_select "nav.menu a[href='/simulador']", text: "Simulador"
  end
end
