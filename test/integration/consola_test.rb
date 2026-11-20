require "test_helper"

# La consola de demo: desde aquí se disparan las acciones y se ve qué hace la central.
class ConsolaTest < ActionDispatch::IntegrationTest
  Simulado = Notification::Proveedores::Simulado

  setup { sembrar }

  def emitir(**opciones)
    post "/acciones/emitir_certificado",
         params: { empresa_id: 1, usuario_id: 1, curso: "Excel avanzado" }.merge(opciones)
    follow_redirect!
  end

  test "35: la zona de resultado muestra el certificado emitido y sube el contador" do
    get "/consola"
    assert_includes response.body, "Certificados emitidos en esta empresa: 0"

    emitir

    assert_match(/Certificado ##{Certificado.sole.id} emitido\. Solicitud \h{8}\./, response.body)
    assert_includes response.body, "Certificados emitidos en esta empresa: 1"
  end

  test "35: con falla a la mitad muestra la falla y el contador no sube" do
    emitir
    emitir(fallar_a_la_mitad: "1")

    assert_includes response.body, "La acción falló a la mitad: no se guardó el certificado ni la notificación."
    assert_includes response.body, "Certificados emitidos en esta empresa: 1"
  end

  test "35: un error de validación se muestra con el mismo mensaje que da la API" do
    emitir(usuario_id: 9)

    assert_select ".resultado.error", text: "la persona no pertenece a la empresa"
  end

  test "la consola conserva la empresa, la persona y el curso elegidos" do
    get "/consola", params: { empresa_id: 3, usuario_id: 18, curso: "Tablas dinámicas" }

    assert_select "select[name=empresa_id] option[selected]", text: "Clínica Austral"
    assert_select "select[name=usuario_id] option[selected]", text: "Sergio Campos"
    assert_select "select[name=curso] option[selected]", text: "Tablas dinámicas"
    assert_select "select[name=usuario_id] option", count: 8
  end

  test "la consola muestra pendientes, solicitudes con su recorrido, políticas y bandeja" do
    emitir
    get "/consola"
    assert_select "#pendientes tbody tr", count: 1
    assert_includes response.body, "certificado_emitido"

    despachar
    avisar
    get "/consola"

    assert_select "#pendientes tbody tr", count: 0
    assert_select "#solicitudes .recorrido", text: /recibida.*decision_enviar.*enviada.*entregada/m
    assert_select "#bandeja .correo", count: 1
    # El correo se ve como llegaría: asunto, vista previa y el HTML con su botón.
    assert_select "#bandeja .correo .vista-previa-bandeja"
    assert_select "#bandeja .correo .html-correo h1"
    assert_select "#bandeja .correo .html-correo a.boton"
    assert_includes response.body, "Tu certificado de Excel avanzado está listo"
    assert_select "#politicas td", text: "email"
  end

  test "las listas se pueden pedir solas, para refrescarlas cada 2 segundos" do
    emitir
    get "/consola/listas", params: { empresa_id: 1 }

    assert_response :ok
    assert_not_includes response.body, "<html", "es un fragmento, sin el marco de la página"
    assert_select "#pendientes tbody tr", count: 1
    assert_includes response.body, "Certificados emitidos en esta empresa: 1"
  end

  test "las solicitudes de la consola son solo las de la empresa elegida" do
    emitir
    get "/consola", params: { empresa_id: 2 }

    assert_select "#solicitudes .recorrido", count: 0
    assert_select "#pendientes tbody tr", count: 1 # los pendientes son de todas las empresas
  end

  test "parámetros con forma de objeto no rompen la consola" do
    ["/consola", "/consola/listas"].each do |ruta|
      get ruta, params: { empresa_id: { a: 1 }, usuario_id: { a: 1 }, curso: { a: 1 } }

      assert_response :ok
    end
    assert_includes response.body, "Últimas solicitudes de Andes Capacitación"
  end

  test "la lista de pendientes muestra los primeros 50 y avisa cuántos hay en total" do
    CertificadoEmitido.send(empresa: 1, destinatarios: (1001..1060).to_a,
      datos: { certificado_id: 1, curso: "Excel avanzado", imagen_curso: "/cursos/excel-avanzado.svg",
               link_certificado: "https://ejemplo.test/c/1" })

    get "/consola"

    assert_select "#pendientes tbody tr", count: 50
    assert_select "#pendientes .cuenta", text: "60"
    assert_includes response.body, "Se muestran los primeros 50"
  end

  test "intentar apagar lo crítico muestra el rechazo" do
    post "/consola/apagar_critico", params: { empresa_id: 1 }
    follow_redirect!

    assert_select ".resultado.error", text: /Una política no puede dejar lo crítico sin canal/
    assert_equal 1, Notification::PoliticaCliente.count
  end

  test "el interruptor apaga y enciende el proveedor, y la consola muestra el estado del canal" do
    post "/consola/proveedor", params: { encender: "0", empresa_id: 1 }
    follow_redirect!
    assert_not Simulado.encendido?
    assert_includes response.body, "Proveedor apagado"

    enviar_certificado(Usuario.find(1))
    despachar
    get "/consola"
    assert_includes response.body, "1 falla consecutiva"
    assert_match(/próximo intento en \d+ s/, response.body)

    post "/consola/proveedor", params: { encender: "1", empresa_id: 1 }
    follow_redirect!
    assert Simulado.encendido?
    assert_includes response.body, "Proveedor encendido"
  end

  test "un dato con HTML se muestra como texto, no se interpreta" do
    post "/api/certificados", params: { empresa_id: 1, usuario_id: 1, curso: "<b>x</b>" }, as: :json
    despachar

    ["/consola", "/historial", "/consola/listas?empresa_id=1"].each do |ruta|
      get ruta

      assert_includes response.body, "&lt;b&gt;x&lt;/b&gt;", "#{ruta} debería mostrar el dato escapado"
      assert_not_includes response.body, "<b>x</b>", "#{ruta} no debería interpretar el HTML"
    end
  end

  test "reiniciar demo deja la base como recién sembrada" do
    emitir
    post "/consola/reiniciar"
    follow_redirect!

    assert_includes response.body, "Demo reiniciada"
    assert_equal 0, Certificado.where(empresa_id: 1).count
    assert_equal 0, Notification::Pendiente.count
  end

  test "proveedor, apagar lo crítico y reiniciar vuelven a la consola" do
    post "/consola/proveedor", params: { encender: "0", empresa_id: 2, usuario_id: 9, curso: "Excel básico" }
    assert_redirected_to "/consola?curso=Excel+b%C3%A1sico&empresa_id=2&usuario_id=9"

    post "/consola/apagar_critico", params: { empresa_id: 1 }
    assert_redirected_to "/consola?empresa_id=1"

    post "/consola/reiniciar"
    assert_redirected_to "/consola"
  end

  test "un error de validación vuelve a la consola con el error" do
    post "/acciones/emitir_certificado", params: { empresa_id: 1, usuario_id: 9, curso: "Excel avanzado" }

    assert_redirected_to "/consola?curso=Excel+avanzado&empresa_id=1&usuario_id=9"
    follow_redirect!
    assert_select ".resultado.error"
  end

  test "el selector de empresa lleva a la consola de esa empresa" do
    get "/consola"

    assert_select "select[name=empresa_id][onchange*='/consola?empresa_id=']"
  end

  test "las secciones de la consola van en el orden nuevo" do
    get "/consola"

    titulos = css_select("main h2").map { |titulo| titulo.text.squish }
    assert_equal ["1. Acciones de negocio", "2. Últimas solicitudes de Andes Capacitación",
                  "3. Bandeja del proveedor simulado", "4. Proveedor de correo (simulado) y políticas",
                  "5. Pendientes 0"], titulos
  end

  test "el refresco trae los tres pedazos con los mismos ids que la consola" do
    get "/consola"
    assert_select "#vivo-solicitudes #solicitudes"
    assert_select "#vivo-solicitudes #bandeja"
    assert_select "section.tarjeta #vivo-estado", text: /Certificados emitidos en esta empresa: 0/
    assert_select "#vivo-pendientes #pendientes"
    assert_select ".estado-general", count: 1

    get "/consola/listas", params: { empresa_id: 1 }
    assert_not_includes response.body, "<html"
    assert_select "#vivo-solicitudes #solicitudes"
    assert_select "#vivo-solicitudes #bandeja"
    assert_select "#vivo-estado", text: /Proveedor encendido/
    assert_select "#vivo-pendientes #pendientes"
  end

  test "después de una acción el resultado tiene el link Ver el recorrido" do
    emitir
    assert_select ".resultado a[href='#solicitudes']", text: "Ver el recorrido"

    post "/acciones/recordatorio", params: { empresa_id: 1, usuario_id: 2, curso: "Excel básico" }
    follow_redirect!
    assert_select ".resultado a[href='#solicitudes']", text: "Ver el recorrido"
  end

  test "con la casilla de doble llamada también aparece Ver el recorrido" do
    emitir(llamar_dos_veces: "1")

    assert_select ".resultado a[href='#solicitudes']", text: "Ver el recorrido"
  end

  test "sin Ver el recorrido cuando no hubo una acción ejecutada" do
    emitir(fallar_a_la_mitad: "1")
    assert_select ".resultado a", count: 0

    post "/consola/apagar_critico", params: { empresa_id: 1 }
    follow_redirect!
    assert_select ".resultado a", count: 0

    post "/consola/reiniciar"
    follow_redirect!
    assert_select ".resultado a", count: 0
  end

  test "qué probar está en la consola, plegado, con los diez escenarios" do
    get "/consola"

    assert_select "details.que-probar:not([open])" do
      assert_select "summary", text: "Qué probar (diez escenarios)"
      assert_equal ["Escenario", "Dónde", "Qué se ve"], css_select("details.que-probar th").map(&:text)
      assert_select "tbody tr", count: 10
      Demo::Declaraciones::ESCENARIOS.each do |_numero, escenario, donde, que_se_ve|
        assert_select "td", text: escenario
        assert_select "td", text: donde
        assert_select "td", text: que_se_ve
      end
    end
  end

  test "la bajada de la consola explica el ejemplo" do
    get "/consola"

    assert_includes css_select(".bajada").text.squish,
                    "El ejemplo es una plataforma de capacitación: la notificación principal es el certificado " \
                    "de un curso. También están definidos un recordatorio, una encuesta y un aviso de cumpleaños " \
                    "a toda la empresa."
  end

  test "72: el botón de cumpleaños avisa a toda la empresa los cumpleaños de hoy" do
    get "/consola"

    assert_select "button[formaction='/acciones/cumpleanos']", text: "Avisar los cumpleaños de hoy"
  end
end
