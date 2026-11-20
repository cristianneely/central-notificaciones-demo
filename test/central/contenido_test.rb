require "test_helper"

# El contenido de una definición es una lista de piezas. Rellenarlo es reemplazar cada
# {marcador} por el dato del envío, sin cambiar el orden ni dar formato de ningún canal.
class ContenidoTest < ActiveSupport::TestCase
  class Completa < Notification
    criticidad :informativa
    datos      :nombre, :curso, :foto, :link
    unica_por  :curso

    contenido do
      titulo    "Hola {nombre}"
      resumen   "Novedades de {curso}."
      parrafo   "Terminaste {curso}."
      destacado "Muy bien, {nombre}"
      lista     "Curso: {curso}", "Persona: {nombre}"
      imagen    "{foto}", alt: "Foto de {nombre}"
      boton     "Ver {curso}", link: "{link}"
    end
  end

  setup do
    @definicion = Notification::Catalogo.new.registrar(Completa)
    @datos = { "nombre" => "Ana", "curso" => "Excel", "foto" => "https://ejemplo.test/f.png",
               "link" => "https://ejemplo.test/c" }
  end

  test "44: rellenar devuelve las piezas en el orden declarado, con los datos puestos" do
    contenido = Notification::Contenido.rellenar(@definicion, @datos)

    assert_equal "completa", contenido.notificacion
    assert_equal [
      { tipo: :titulo, texto: "Hola Ana" },
      { tipo: :resumen, texto: "Novedades de Excel." },
      { tipo: :parrafo, texto: "Terminaste Excel." },
      { tipo: :destacado, texto: "Muy bien, Ana" },
      { tipo: :lista, items: ["Curso: Excel", "Persona: Ana"] },
      { tipo: :imagen, url: "https://ejemplo.test/f.png", alt: "Foto de Ana" },
      { tipo: :boton, texto: "Ver Excel", link: "https://ejemplo.test/c" }
    ], contenido.piezas
  end

  test "44: el contenido rellenado sabe su título, su resumen y sus piezas por tipo" do
    contenido = Notification::Contenido.rellenar(@definicion, @datos)

    assert_equal "Hola Ana", contenido.titulo
    assert_equal "Novedades de Excel.", contenido.resumen
    assert_equal [{ tipo: :boton, texto: "Ver Excel", link: "https://ejemplo.test/c" }], contenido.de(:boton)
  end

  test "44: rellenar no modifica la definición" do
    Notification::Contenido.rellenar(@definicion, @datos)

    assert_equal "Hola {nombre}", @definicion.contenido.first[:texto]
  end

  test "44: la lista también se puede declarar con un arreglo" do
    piezas = Notification::Contenido.declarar { lista ["Uno", "Dos"] }

    assert_equal [{ tipo: :lista, items: ["Uno", "Dos"] }], piezas
  end
end
