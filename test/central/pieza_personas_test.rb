require "test_helper"

# La pieza `personas "{dato}"`: una lista de personas, cada una con su nombre y su foto,
# que crece según cuánta gente traiga el envío (por ejemplo, los cumpleañeros del día).
# Cada canal la dibuja a su manera y dice qué degradó.
class PiezaPersonasTest < ActiveSupport::TestCase
  class ConPersonas < Notification
    criticidad :opcional
    datos      :fecha, :gente
    unica_por  :fecha

    contenido do
      titulo    "Cumpleaños de hoy: {gente}"
      resumen   "Hoy celebramos a {gente}."
      personas  "{gente}"
      destacado "¡Que lo pasen increíble!"
    end
  end

  GENTE = [{ "nombre" => "Ana Soto", "foto" => "/personas/ana-soto.svg" },
           { "nombre" => "Bruno <Díaz>", "foto" => "/personas/bruno-diaz.svg" }].freeze

  setup do
    @definicion = Notification::Catalogo.new.registrar(ConPersonas)
    @contenido = Notification::Contenido.rellenar(
      @definicion, { fecha: "20-11-2026", gente: GENTE }
    )
  end

  def canal(nombre) = Notification::Canales.buscar(nombre)

  # Arma una clase con este contenido y devuelve los errores del catálogo.
  def errores_de(&bloque)
    nueva = Class.new(Notification)
    Module.new.const_set("DePrueba", nueva)
    nueva.criticidad :opcional
    nueva.datos :gente
    nueva.unica_por :gente
    nueva.contenido(&bloque)
    error = assert_raises(Notification::DefinicionInvalida) { Notification::Catalogo.new.registrar(nueva) }
    error.errores
  end

  test "68: rellenar pone en la pieza la lista de personas, con nombre y foto" do
    assert_equal({ tipo: :personas,
                   gente: [{ nombre: "Ana Soto", foto: "/personas/ana-soto.svg" },
                           { nombre: "Bruno <Díaz>", foto: "/personas/bruno-diaz.svg" }] },
                 @contenido.de(:personas).first)
    assert_equal "Cumpleaños de hoy: Ana Soto y Bruno <Díaz>", @contenido.titulo
  end

  test "76: un {dato} con una lista de personas se escribe con sus nombres, en cualquier texto" do
    nombres = ->(gente) { Notification::Contenido.rellenar(@definicion, { fecha: "x", gente: gente }).titulo }
    ana = { "nombre" => "Ana Soto", "foto" => "/a.svg" }
    bruno = { nombre: "Bruno Díaz", foto: "/b.svg" }
    carla = { "nombre" => "Carla Muñoz", "foto" => "/c.svg" }

    assert_equal "Cumpleaños de hoy: Ana Soto", nombres.([ana])
    assert_equal "Cumpleaños de hoy: Ana Soto y Bruno Díaz", nombres.([ana, bruno])
    assert_equal "Cumpleaños de hoy: Ana Soto, Bruno Díaz y Carla Muñoz", nombres.([ana, bruno, carla])
    assert_equal "Hoy celebramos a Ana Soto y Bruno <Díaz>.", @contenido.resumen
  end

  test "68: el catálogo acepta personas con un dato declarado" do
    assert_equal "con_personas", @definicion.nombre
  end

  test "68: personas mal escrita da un error claro" do
    forma = [%(personas se escribe: personas "{dato}")]

    assert_equal forma, errores_de { titulo "t"; resumen "r"; personas "gente" }
    assert_equal forma, errores_de { titulo "t"; resumen "r"; personas "{gente} y {gente}" }
    assert_equal forma, errores_de { titulo "t"; resumen "r"; personas "{gente}", alt: "x" }
    assert_equal forma, errores_de { titulo "t"; resumen "r"; personas }
  end

  test "68: personas con un dato no declarado" do
    assert_equal ["el contenido usa un dato no declarado: otro"],
                 errores_de { titulo "t"; resumen "r"; personas "{otro}" }
  end

  test "69: email dibuja una fila de fotos con el nombre debajo, escapando cada dato" do
    mensaje = canal("email").adaptar(@contenido)

    assert_includes mensaje[:html],
                    %(<table class="personas"><tr>) +
                    %(<td><img src="/personas/ana-soto.svg" alt="Ana Soto" width="64"><br>Ana Soto</td>) +
                    %(<td><img src="/personas/bruno-diaz.svg" alt="Bruno &lt;Díaz&gt;" width="64"><br>Bruno &lt;Díaz&gt;</td>) +
                    %(</tr></table>)
    assert_includes mensaje[:texto], "- Ana Soto\n- Bruno <Díaz>"
    assert_equal [], canal("email").notas(@contenido)
  end

  test "69: Slack dibuja un bloque con foto chica y nombre por persona" do
    bloques = canal("slack").adaptar(@contenido)[:blocks]

    assert_includes bloques, { type: "context", elements: [
      { type: "image", image_url: "/personas/ana-soto.svg", alt_text: "Ana Soto" },
      { type: "mrkdwn", text: "Ana Soto" }
    ] }
    assert_includes bloques, { type: "context", elements: [
      { type: "image", image_url: "/personas/bruno-diaz.svg", alt_text: "Bruno <Díaz>" },
      { type: "mrkdwn", text: "Bruno &lt;Díaz&gt;" }
    ] }
    assert_equal [], canal("slack").notas(@contenido)
  end

  test "69: WhatsApp pasa las personas a nombres y adjunta la foto de la primera" do
    mensaje = canal("whatsapp").adaptar(@contenido)

    assert_includes mensaje[:texto], "- Ana Soto\n- Bruno <Díaz>"
    assert_equal({ url: "/personas/ana-soto.svg", alt: "Ana Soto" }, mensaje[:imagen])
    assert_includes canal("whatsapp").notas(@contenido), "Personas: pasan a nombres; se adjunta la foto de la primera"
  end

  test "69: si hay una pieza imagen, WhatsApp y push adjuntan esa y no la foto" do
    piezas = @contenido.piezas + [{ tipo: :imagen, url: "/tarjeta.svg", alt: "Tarjeta" }]
    contenido = Notification::Contenido::Relleno.new(notificacion: "con_personas", piezas: piezas)

    assert_equal "/tarjeta.svg", canal("whatsapp").adaptar(contenido)[:imagen][:url]
    assert_equal "/tarjeta.svg", canal("push").adaptar(contenido)[:imagen]
    # Y la nota de degradación lo dice: las personas no ponen la imagen.
    assert_includes canal("whatsapp").notas(contenido), "Personas: pasan a nombres"
    assert_not_includes canal("whatsapp").notas(contenido), "Personas: pasan a nombres; se adjunta la foto de la primera"
    assert_includes canal("push").notas(contenido), "Personas: se omite"
    assert_not_includes canal("push").notas(contenido), "Personas: solo la foto de la primera"
  end

  test "69: SMS omite las personas: el resumen ya trae los nombres" do
    assert_equal "Hoy celebramos a Ana Soto y Bruno <Díaz>.", canal("sms").adaptar(@contenido)[:texto]
    assert_includes canal("sms").notas(@contenido), "Personas: se omite"
  end

  test "69: push muestra la foto de la primera persona como imagen" do
    assert_equal "/personas/ana-soto.svg", canal("push").adaptar(@contenido)[:imagen]
    assert_includes canal("push").notas(@contenido), "Personas: solo la foto de la primera"
  end
end
