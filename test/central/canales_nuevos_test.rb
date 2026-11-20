require "test_helper"

# Slack, WhatsApp y SMS: cada canal dibuja las mismas piezas a su manera y dice qué
# degradó (tabla de la sección 2.1.5). Son canales simulados: existen para el simulador
# y no entran a la política por defecto, así que la parte 1 sigue saliendo por email.
class CanalesNuevosTest < ActiveSupport::TestCase
  PIEZAS = [
    { tipo: :titulo, texto: "Ana pidió vacaciones" },
    { tipo: :resumen, texto: "Ana pidió vacaciones del 2 al 6 de diciembre." },
    { tipo: :parrafo, texto: "Espera tu respuesta." },
    { tipo: :destacado, texto: "Son 5 días hábiles" },
    { tipo: :lista, items: ["Desde: 2-12", "Hasta: 6-12"] },
    { tipo: :imagen, url: "https://ejemplo.test/i.png", alt: "Calendario" },
    { tipo: :boton, texto: "Revisar solicitud", link: "https://ejemplo.test/solicitudes/55" }
  ].freeze

  def contenido(piezas = PIEZAS, notificacion: "solicitud_vacaciones")
    Notification::Contenido::Relleno.new(notificacion: notificacion, piezas: piezas)
  end

  def canal(nombre) = Notification::Canales.buscar(nombre)

  test "50: Slack arma un mensaje con bloques y el resumen como texto del aviso" do
    mensaje = canal("slack").adaptar(contenido)

    assert_equal "Ana pidió vacaciones del 2 al 6 de diciembre.", mensaje[:text]
    assert_equal [
      { type: "header", text: { type: "plain_text", text: "Ana pidió vacaciones" } },
      { type: "section", text: { type: "mrkdwn", text: "Espera tu respuesta." } },
      { type: "section", text: { type: "mrkdwn", text: "*Son 5 días hábiles*" } },
      { type: "section", text: { type: "mrkdwn", text: "• Desde: 2-12\n• Hasta: 6-12" } },
      { type: "image", image_url: "https://ejemplo.test/i.png", alt_text: "Calendario" },
      { type: "actions", elements: [{ type: "button", text: { type: "plain_text", text: "Revisar solicitud" },
                                      url: "https://ejemplo.test/solicitudes/55" }] }
    ], mensaje[:blocks]
    assert_equal [], canal("slack").notas(contenido)
  end

  test "50: Slack escapa los caracteres que su formato usa para links" do
    piezas = [{ tipo: :titulo, texto: "t" }, { tipo: :resumen, texto: "r" }, { tipo: :parrafo, texto: "a < b & c > d" }]

    assert_equal "a &lt; b &amp; c &gt; d", canal("slack").adaptar(contenido(piezas))[:blocks][1][:text][:text]
  end

  test "51: WhatsApp con plantilla aprobada: texto con negrita, imagen adjunta y botón de la plantilla" do
    mensaje = canal("whatsapp").adaptar(contenido(notificacion: "certificado_emitido"))

    assert_equal "certificado_emitido", mensaje[:plantilla]
    assert_equal "*Ana pidió vacaciones*\n\nEspera tu respuesta.\n\n*Son 5 días hábiles*\n\n- Desde: 2-12\n- Hasta: 6-12",
                 mensaje[:texto]
    assert_equal({ url: "https://ejemplo.test/i.png", alt: "Calendario" }, mensaje[:imagen])
    assert_equal({ texto: "Revisar solicitud", link: "https://ejemplo.test/solicitudes/55" }, mensaje[:boton])
    assert_equal ["Resumen: se omite", "Lista: pasa a líneas con guion"],
                 canal("whatsapp").notas(contenido(notificacion: "certificado_emitido"))
  end

  test "52: WhatsApp sin plantilla aprobada: el botón pasa a link dentro del texto" do
    mensaje = canal("whatsapp").adaptar(contenido)

    assert_nil mensaje[:plantilla]
    assert_nil mensaje[:boton]
    assert mensaje[:texto].end_with?("\n\nRevisar solicitud: https://ejemplo.test/solicitudes/55")
    assert_equal ["Resumen: se omite", "Lista: pasa a líneas con guion", "Botón: pasa a link (sin plantilla aprobada)"],
                 canal("whatsapp").notas(contenido)
  end

  test "53: SMS: el resumen y un link corto" do
    mensaje = canal("sms").adaptar(contenido)

    assert_match %r{\AAna pidió vacaciones del 2 al 6 de diciembre\. https://nj\.test/\h{6}\z}, mensaje[:texto]
    assert_equal ["Título: se omite", "Párrafo: se omite", "Destacado: se omite", "Lista: se omite",
                  "Imagen: se omite", "Botón: pasa a link corto"], canal("sms").notas(contenido)
  end

  test "53: el link corto de un mismo link es siempre el mismo" do
    assert_equal canal("sms").adaptar(contenido)[:texto], canal("sms").adaptar(contenido)[:texto]
  end

  test "54: SMS nunca pasa de 160 caracteres y conserva el link" do
    largo = [{ tipo: :titulo, texto: "t" }, { tipo: :resumen, texto: "Palabra " * 40 },
             { tipo: :boton, texto: "Ir", link: "https://ejemplo.test/#{"x" * 300}" }]
    texto = canal("sms").adaptar(contenido(largo))[:texto]

    assert_operator texto.length, :<=, 160
    assert_match %r{… https://nj\.test/\h{6}\z}, texto
  end

  test "54: SMS sin botón: solo el resumen, recortado a 160" do
    largo = [{ tipo: :titulo, texto: "t" }, { tipo: :resumen, texto: "a" * 300 }]
    texto = canal("sms").adaptar(contenido(largo))[:texto]

    assert_equal 160, texto.length
    assert texto.end_with?("…")
  end

  test "55: las notas solo nombran las piezas que trae el contenido" do
    corto = [{ tipo: :titulo, texto: "t" }, { tipo: :resumen, texto: "r" }]

    assert_equal ["Título: se omite"], canal("sms").notas(contenido(corto))
    assert_equal ["Resumen: se omite"], canal("whatsapp").notas(contenido(corto))
  end

  test "56: los canales nuevos existen pero no entran a la política: todo sigue saliendo por email" do
    sembrar
    definiciones_antes = Notification.catalogo.todas.dup

    assert_equal %w[email slack whatsapp sms], Notification::Canales.nombres
    Notification::Configuracion::POLITICA_POR_DEFECTO.each_value { |canales| assert_equal ["email"], canales }

    solicitud = enviar_certificado(Usuario.find(1))
    despachar
    assert_equal %w[email email], recorrido(solicitud).last(2).map(&:canal)
    assert_equal 1, bandeja.size
    assert_equal definiciones_antes, Notification.catalogo.todas
  end

  test "56: el proveedor simulado de mensajería acepta y no guarda nada" do
    resultado = Notification::Proveedores::MensajeriaSimulada.entregar(canal: "sms", mensaje: { texto: "x" },
                                                                       para: "+56900000000")

    assert resultado.aceptado?
    assert_match(/\Asim-sms-\h{6}\z/, resultado.id_proveedor)
  end
end
