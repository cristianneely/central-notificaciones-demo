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
                 Notification::PoliticaCliente.pluck(:empresa_id, :criticidad, :canal, :habilitado)
  end

  test "sembrar_si_vacia no repite la siembra" do
    Demo::Siembra.sembrar_si_vacia
    Demo::Siembra.sembrar_si_vacia

    assert_equal 3, Empresa.count
    assert_equal 24, Usuario.count
  end

  test "37: el historial de ejemplo, sembrado con el mismo código de la central" do
    Demo::Siembra.ejecutar

    assert_equal 0, Notification::Pendiente.count
    estados = [2, 3].flat_map { |empresa_id| Notification::Historial.filas(empresa_id: empresa_id) }.map(&:estado)
    ["Entregada", "Rebotada", "Duplicada", "Retenida: límite de frecuencia",
     "No enviada: política del cliente"].each do |estado|
      assert_includes estados, estado
    end
    assert_equal({ "Entregada" => 5, "Rebotada" => 1, "Duplicada" => 1, "Retenida: límite de frecuencia" => 1,
                   "No enviada: política del cliente" => 1 }, estados.tally)

    assert_equal 0, Notification::Auditoria.where(empresa_id: 1).count, "Andes Capacitación parte sin historial"
    assert_empty Notification::Historial.filas(empresa_id: 1)
    assert_equal ["interno"], Notification::Auditoria.where(evento: "recibida").map { |f| f.detalle["origen"] }.uniq
    assert_equal 3, Certificado.count
  end

  test "37: preparar la base siembra también el historial de ejemplo, una sola vez" do
    Demo::Siembra.sembrar_si_vacia
    filas = Notification::Auditoria.count
    Demo::Siembra.sembrar_si_vacia

    assert_operator filas, :>, 0
    assert_equal filas, Notification::Auditoria.count
  end

  test "reiniciar la demo vuelve a los datos semilla y la auditoría sigue protegida" do
    Demo::Siembra.ejecutar
    recien_sembrada = [Empresa.count, Usuario.count, Certificado.count, Notification::Auditoria.count,
                       Notification::Proveedores::CorreoSimulado.count, Notification::PoliticaCliente.count]
    Certificados::EmitirCertificado.ejecutar(empresa_id: 1, usuario_id: 1, curso: "Excel básico")
    Notification::Proveedores::Simulado.apagar
    Notification::Despachador.vuelta

    Demo::Reinicio.ejecutar

    assert_equal recien_sembrada,
                 [Empresa.count, Usuario.count, Certificado.count, Notification::Auditoria.count,
                  Notification::Proveedores::CorreoSimulado.count, Notification::PoliticaCliente.count]
    assert_equal 0, Notification::Pendiente.count
    assert Notification::Proveedores::Simulado.encendido?
    assert_equal 0, Notification::EstadoCanal.count
    assert_equal "sim-000001", Notification::Proveedores::CorreoSimulado.order(:id).first.id_proveedor
    assert_raises(ActiveRecord::StatementInvalid) { Notification::Auditoria.delete_all }
  end

  test "los cursos de la demo" do
    assert_equal ["Excel básico", "Excel avanzado", "Tablas dinámicas", "Power BI inicial"], Cursos::LISTA
  end
end
