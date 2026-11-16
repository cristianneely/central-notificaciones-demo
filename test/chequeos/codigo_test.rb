require "test_helper"

# Pruebas que revisan el código mismo, no su comportamiento. Reemplazan, en la demo, a
# los chequeos automáticos de la revisión de código que propone el documento.
class CodigoTest < ActiveSupport::TestCase
  RAIZ = Rails.root

  # Los archivos de la aplicación (sin las pruebas) cuyo texto calza con el patrón.
  def archivos_con(patron, carpetas: %w[app config db lib])
    carpetas.flat_map { |carpeta| Dir[RAIZ.join(carpeta, "**/*.{rb,erb,rake}")] }
            .select { |archivo| File.read(archivo).match?(patron) }
            .map { |archivo| Pathname(archivo).relative_path_from(RAIZ).to_s }
            .sort
  end

  test "28: chequeo R1, solo el canal email invoca la entrega del proveedor" do
    entrega_del_proveedor = /(Proveedores::\w+|Simulado)\.entregar\b/

    assert_equal ["app/central/notification/canales/email.rb"], archivos_con(entrega_del_proveedor)
  end
end
