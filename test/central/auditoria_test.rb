require "test_helper"

# R10: el historial es inmodificable. No depende de que el código se porte bien:
# la base misma rechaza los cambios con disparadores.
class AuditoriaTest < ActiveSupport::TestCase
  setup do
    sembrar
    enviar_certificado(Usuario.find(1))
    @fila = Notification::Auditoria.sole
  end

  test "12: la base rechaza modificar una fila de la auditoría" do
    error = assert_raises(ActiveRecord::StatementInvalid) do
      Notification::Auditoria.where(id: @fila.id).update_all(evento: "enviada")
    end

    assert_includes error.message, "auditoria: solo se puede agregar"
    assert_equal "recibida", @fila.reload.evento
  end

  test "12: la base rechaza borrar una fila de la auditoría" do
    error = assert_raises(ActiveRecord::StatementInvalid) do
      Notification::Auditoria.where(id: @fila.id).delete_all
    end

    assert_includes error.message, "auditoria: solo se puede agregar"
    assert_equal 1, Notification::Auditoria.count
  end

  test "12: agregar filas sigue funcionando después de un rechazo" do
    assert_raises(ActiveRecord::StatementInvalid) { Notification::Auditoria.delete_all }
    enviar_certificado(Usuario.find(2))

    assert_equal 2, Notification::Auditoria.count
  end
end
