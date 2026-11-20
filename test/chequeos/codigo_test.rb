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

  test "27: chequeo R9, ninguna puerta llama a send(): solo las acciones de negocio" do
    clases = Notification.catalogo.todas.map { |definicion| definicion.clase.name }
    assert_equal 5, clases.size
    # Ni el nombre de una notificación ni una llamada a send() o a sus equivalentes.
    llamada_a_send = /\b(#{clases.join("|")})\b|\.\s*(send|deliver|public_send|__send__)\b/

    assert_empty archivos_con(llamada_a_send, carpetas: %w[app/controllers])
    assert_not_empty Dir[RAIZ.join("app/controllers/**/*.rb")]
  end

  test "27: las acciones de negocio sí llaman a send()" do
    assert_includes archivos_con(/CertificadoEmitido\.send\b/, carpetas: %w[app/modulos]),
                    "app/modulos/certificados/emitir_certificado.rb"
  end

  test "28: chequeo R1, solo los canales invocan la entrega de un proveedor" do
    entrega_del_proveedor = /(Proveedores::\w+|Simulado|MensajeriaSimulada)\.entregar\b/

    assert_equal %w[email slack sms whatsapp].map { |canal| "app/central/notification/canales/#{canal}.rb" },
                 archivos_con(entrega_del_proveedor)
  end
end
