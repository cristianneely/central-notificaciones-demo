require "test_helper"

# Cómo dibuja el canal email cada pieza del contenido (tabla de la sección 2.1.5): el
# título es el asunto y el encabezado, el resumen la vista previa en la bandeja, y el
# resto va en HTML. Además arma una versión en texto plano.
class CanalEmailTest < ActiveSupport::TestCase
  PIEZAS = [
    { tipo: :titulo, texto: "Tu certificado está listo" },
    { tipo: :resumen, texto: "Descarga tu certificado." },
    { tipo: :parrafo, texto: "Felicitaciones." },
    { tipo: :destacado, texto: "Nota final: 7,0" },
    { tipo: :lista, items: ["Curso: Excel", "Horas: 20"] },
    { tipo: :imagen, url: "https://ejemplo.test/sello.png", alt: "Sello del curso" },
    { tipo: :boton, texto: "Descargar", link: "https://ejemplo.test/c/1" }
  ].freeze

  def contenido(piezas = PIEZAS)
    Notification::Contenido::Relleno.new(notificacion: "certificado_emitido", piezas: piezas)
  end

  def correo(piezas = PIEZAS)
    Notification::Canales::Email.new.adaptar(contenido(piezas))
  end

  test "46: el título es el asunto y el resumen la vista previa" do
    assert_equal "Tu certificado está listo", correo[:asunto]
    assert_equal "Descarga tu certificado.", correo[:vista_previa]
  end

  test "46: el HTML dibuja cada pieza, en orden" do
    html = correo[:html]

    assert_includes html, %(<span class="vista-previa" style="display:none">Descarga tu certificado.</span>)
    assert_includes html, "<h1>Tu certificado está listo</h1>"
    assert_includes html, "<p>Felicitaciones.</p>"
    assert_includes html, "<p><strong>Nota final: 7,0</strong></p>"
    assert_includes html, "<ul><li>Curso: Excel</li><li>Horas: 20</li></ul>"
    assert_includes html, %(<img src="https://ejemplo.test/sello.png" alt="Sello del curso">)
    assert_includes html, %(<a class="boton" href="https://ejemplo.test/c/1">Descargar</a>)
    posiciones = ["<h1>", "<p>Felicitaciones", "<strong>", "<ul>", "<img", "<a class"].map { |marca| html.index(marca) }
    assert_equal posiciones.sort, posiciones
  end

  test "47: la versión en texto plano trae todo, sin HTML" do
    assert_equal <<~TEXTO.chomp, correo[:texto]
      Tu certificado está listo

      Felicitaciones.

      Nota final: 7,0

      - Curso: Excel
      - Horas: 20

      Sello del curso: https://ejemplo.test/sello.png

      Descargar: https://ejemplo.test/c/1
    TEXTO
  end

  test "48: un dato con caracteres de HTML sale escapado" do
    html = correo([{ tipo: :titulo, texto: "<b>Hola</b> & chao" },
                   { tipo: :resumen, texto: "x" },
                   { tipo: :boton, texto: "Ir", link: %(https://ejemplo.test/?a=1&b="2") }])[:html]

    assert_includes html, "<h1>&lt;b&gt;Hola&lt;/b&gt; &amp; chao</h1>"
    assert_includes html, %(href="https://ejemplo.test/?a=1&amp;b=&quot;2&quot;")
    assert_not_includes html, "<b>"
  end

  test "49: el email sabe dibujar todas las piezas: no degrada nada" do
    assert_equal [], Notification::Canales::Email.new.notas(contenido)
  end
end
