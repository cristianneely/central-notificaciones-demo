require "test_helper"

# Test 31 de la spec: las pantallas cargan y todas muestran el aviso de datos ficticios
# (decisión 9). En esta etapa solo existe la consola (/); /catalogo, /historial y /acerca
# se agregan a esta misma prueba cuando existan.
class PantallasTest < ActionDispatch::IntegrationTest
  AVISO = "Demo con datos ficticios. No sale ningún correo real."

  test "la consola de demo carga y muestra el aviso" do
    get "/"

    assert_response :ok
    assert_includes response.body, AVISO
  end
end
