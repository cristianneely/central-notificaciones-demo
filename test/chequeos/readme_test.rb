require "test_helper"

# El README y la página "Acerca" declaran lo mismo: las simplificaciones de la demo y
# dónde se ve cada requisito. Esta prueba evita que se desalineen.
class ReadmeTest < ActiveSupport::TestCase
  README = Rails.root.join("README.md").read

  test "el README declara todas las simplificaciones de la demo" do
    Demo::Declaraciones::SIMPLIFICACIONES.each do |en_el_diseno, en_la_demo|
      assert_includes README, en_el_diseno
      assert_includes README, en_la_demo
    end
  end

  test "el README dice dónde se ve cada requisito" do
    Demo::Declaraciones::REQUISITOS.each do |codigo, que_pide, donde|
      assert_includes README, "| #{codigo} | #{que_pide} | #{donde} |"
    end
  end

  test "el README pide la misma versión de Ruby que fija el proyecto" do
    assert_includes README, "Ruby #{Rails.root.join(".ruby-version").read.strip.delete_prefix("ruby-")}"
  end

  test "el README explica cómo correr la demo y sus pruebas" do
    ["bin/rails db:prepare", "bin/rails server", "bin/rails test", "Notification.define",
     "Notification.send", "No sale ningún correo real"].each do |texto|
      assert_includes README, texto
    end
  end
end
