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

  test "el README tiene los mismos escenarios que la consola" do
    Demo::Declaraciones::ESCENARIOS.each do |numero, escenario, donde, que_se_ve|
      assert_includes README, "| #{numero} | #{escenario} | #{donde} | #{que_se_ve} |"
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

  test "el README explica por qué la operación se llama send" do
    assert_includes README, "Sobre el nombre `send`: el diseño lo llama así y se respetó"
  end

  test "las simplificaciones usan la redacción nueva" do
    nuevas = [
      ["Reintentos con esperas cada vez más largas, de minutos",
       "Esperas de 5, 10 y 20 segundos, por canal: se prueba con el pendiente más crítico y, cuando pasa, " \
       "salen todos por importancia"],
      ["Límite de frecuencia configurable; parte en 3 no críticas por persona y canal cada 24 h",
       "El mismo valor, fijo en la configuración; cuenta la decisión de enviar"],
      ["Tres entradas: web, API y carga masiva (R9)", "Dos: web y API"],
      ["Quién originó la solicitud (R10)",
       "Se anota la notificación, que identifica al módulo dueño, y la entrada (web, api o interno)"],
      ["Envío doble si una máquina cae justo después de que el proveedor acepta (limitación declarada en la propuesta)",
       "Puede ocurrir; no se trata"],
      ["Clave única por notificación, persona y unica_por", "Texto legible, sin resumir"],
      ["Agrupar lo excedente en un resumen (paso siguiente)", "Solo retener"]
    ]
    nuevas.each { |fila| assert_includes Demo::Declaraciones::SIMPLIFICACIONES, fila }
    assert_equal 23, Demo::Declaraciones::SIMPLIFICACIONES.size

    viejas = ["N y período del límite de frecuencia", "fuera del documento", "el documento no fija formato",
              "Resumen para lo excedente (opcional)", "Reintentos con esperas de minutos",
              "no dice si por correo o por proveedor"]
    viejas.each do |texto|
      assert_not_includes README, texto
      assert_not Demo::Declaraciones::SIMPLIFICACIONES.flatten.any? { |celda| celda.include?(texto) }, texto
    end
  end

  test "los textos visibles dicen entrada, no puerta" do
    visibles = [README, *Dir[Rails.root.join("app/views/**/*.erb")].map { |archivo| File.read(archivo) },
                *[Demo::Declaraciones::SIMPLIFICACIONES, Demo::Declaraciones::REQUISITOS,
                  Demo::Declaraciones::ESCENARIOS].flatten.grep(String)]

    visibles.each { |texto| assert_no_match(/puerta/i, texto) }
  end

  test "el README enlaza la propuesta y explica el inicio y la consola" do
    assert_includes README, "las dos APIs del [diseño](#{Demo::Declaraciones::PROPUESTA_URL})"
    assert_includes README, "La página de inicio lleva a la propuesta, a la demo y al código; la consola está en `/consola`."
  end

  test "el README dice cómo volver a los datos de ejemplo, sin el aviso del plan gratuito" do
    assert_includes README, "Para volver a los datos de ejemplo, usa \"Reiniciar demo\" al final de la consola."
    assert_no_match(/plan gratuito|despert|se duerme/i, README)
  end
end
