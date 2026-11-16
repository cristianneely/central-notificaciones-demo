require "test_helper"

# Los datos semilla de la demo: todo ficticio.
class SiembraTest < ActiveSupport::TestCase
  test "datos base: tres empresas, ocho personas por empresa y las personas especiales" do
    sembrar

    assert_equal({ 1 => "Andes Capacitación", 2 => "Minera Los Robles", 3 => "Clínica Austral" },
                 Empresa.order(:id).pluck(:id, :nombre).to_h)
    assert_equal({ 1 => 8, 2 => 8, 3 => 8 }, Usuario.group(:empresa_id).count)

    assert persona("(rebota)", empresa_id: 1).email.end_with?("@rebota.test")
    assert_equal "correo-invalido", persona("(correo inválido)", empresa_id: 1).email
    assert_equal "", persona("(sin correo)", empresa_id: 1).email
    assert persona("(rebota)", empresa_id: 3).email.end_with?("@rebota.test")

    normales = Usuario.where.not("nombre LIKE ?", "%(%")
    assert_equal 20, normales.count
    assert normales.all? { |persona| persona.email.match?(/\A[a-z]+\.[a-z]+@ejemplo\.test\z/) }
  end

  test "datos base: Minera Los Robles tiene lo opcional por email apagado" do
    sembrar

    assert_equal [[2, "opcional", "email", false]],
                 Notification::PoliticaCliente.pluck(:empresa_id, :importancia, :canal, :habilitado)
  end

  test "sembrar_si_vacia no repite la siembra" do
    Demo::Siembra.sembrar_si_vacia
    Demo::Siembra.sembrar_si_vacia

    assert_equal 3, Empresa.count
    assert_equal 24, Usuario.count
  end

  test "los cursos de la demo" do
    assert_equal ["Excel básico", "Excel avanzado", "Tablas dinámicas", "Power BI inicial"], Cursos::LISTA
  end
end
