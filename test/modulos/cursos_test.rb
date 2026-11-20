require "test_helper"

# El módulo de cursos elige la portada de cada curso: la imagen que lleva el certificado.
class CursosTest < ActiveSupport::TestCase
  test "66: cada curso de la lista tiene su portada en public/" do
    Cursos::LISTA.each do |curso|
      ruta = Cursos.imagen(curso)
      assert_match %r{\A/cursos/[a-z0-9-]+\.svg\z}, ruta
      assert Rails.root.join("public#{ruta}").exist?, "falta la portada de #{curso}: #{ruta}"
    end
    assert_equal "/cursos/excel-avanzado.svg", Cursos.imagen("Excel avanzado")
    assert_equal "/cursos/tablas-dinamicas.svg", Cursos.imagen("Tablas dinámicas")
  end

  test "66: un curso que no está en la lista usa la portada genérica" do
    assert_equal "/cursos/curso.svg", Cursos.imagen("Macros con VBA")
    assert Rails.root.join("public/cursos/curso.svg").exist?
  end
end
