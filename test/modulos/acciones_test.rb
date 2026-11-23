require "test_helper"

# Las acciones de negocio de ejemplo. Cada una vive en un solo lugar y es lo único que
# llama a send(); por eso notifican igual sin importar por qué puerta se las llame (R9).
class AccionesTest < ActiveSupport::TestCase
  setup do
    sembrar
    @ana = Usuario.find(1)
  end

  def emitir(**opciones)
    Certificados::EmitirCertificado.ejecutar(
      **{ empresa_id: 1, usuario_id: @ana.id, curso: "Excel avanzado" }.merge(opciones)
    )
  end

  def assert_invalida(mensaje, **opciones)
    error = assert_raises(Certificados::EmitirCertificado::Invalida) { emitir(**opciones) }

    assert_equal mensaje, error.message
    assert_equal 0, Certificado.count
    assert_equal [0, 0, 0], conteos_de_send
  end

  test "emitir certificado crea el certificado y pide la notificación" do
    resultado = emitir

    certificado = Certificado.sole
    assert_equal certificado, resultado.certificado
    assert_equal [1, @ana.id, "Excel avanzado"], [certificado.empresa_id, certificado.usuario_id, certificado.curso]

    pendiente = Notification::Pendiente.sole
    assert_equal resultado.solicitud_id, pendiente.solicitud_id
    assert_equal "certificado_emitido", pendiente.notificacion
    assert_equal({ "certificado_id" => certificado.id, "curso" => "Excel avanzado",
                   "imagen_curso" => "/cursos/excel-avanzado.svg",
                   "link_certificado" => "https://ejemplo.test/certificados/#{certificado.id}" },
                 pendiente.datos)
  end

  test "11: si la acción falla a la mitad no queda ni el certificado ni la notificación" do
    assert_raises(Certificados::EmitirCertificado::FallaSimulada) { emitir(fallar_a_la_mitad: true) }

    assert_equal 0, Certificado.count
    assert_equal 0, Notification::ClaveUnica.count
    assert_equal 0, Notification::Pendiente.count
    assert_equal 0, Notification::Auditoria.count
  end

  test "si la acción llama dos veces a send(), sale una sola notificación" do
    resultado = emitir(llamar_dos_veces: true)

    assert_equal 1, Certificado.count
    assert_equal 1, Notification::Pendiente.count
    assert_equal ["recibida"], eventos(resultado.solicitud_id)
    assert_equal %w[recibida duplicada], Notification::Auditoria.order(:id).pluck(:evento)
  end

  test "emitir certificado valida lo mismo para todas las puertas" do
    assert_invalida "falta empresa_id", empresa_id: nil
    assert_invalida "falta usuario_id", usuario_id: ""
    assert_invalida "falta curso", curso: "   "
    assert_invalida "empresa desconocida", empresa_id: 999
    assert_invalida "empresa desconocida", empresa_id: "1abc"
    assert_invalida "la persona no pertenece a la empresa", usuario_id: 9
    assert_invalida "la persona no pertenece a la empresa", usuario_id: 9999
    assert_invalida "curso demasiado largo", curso: "x" * 101
  end

  test "emitir certificado acepta los ids como texto y un curso de 100 caracteres" do
    resultado = emitir(empresa_id: "1", usuario_id: "1", curso: "x" * 100)

    assert_equal [1, 1], [resultado.certificado.empresa_id, resultado.certificado.usuario_id]
  end

  test "recordatorio de curso: la fecha límite es hoy en Chile más 7 días" do
    travel_to Time.utc(2026, 11, 16, 1, 0) # en Chile todavía es 15 de noviembre
    solicitud = Cursos::EnviarRecordatorio.ejecutar(empresa_id: 1, usuario_id: @ana.id, curso: "Excel básico")

    pendiente = Notification::Pendiente.find_by!(solicitud_id: solicitud)
    assert_equal "recordatorio_curso", pendiente.notificacion
    assert_equal({ "curso" => "Excel básico", "fecha_limite" => "22-11-2026",
                   "link_curso" => "https://ejemplo.test/cursos" }, pendiente.datos)
  end

  test "encuesta de satisfacción" do
    solicitud = Cursos::EnviarEncuesta.ejecutar(empresa_id: "1", usuario_id: "1", curso: "Excel básico")

    pendiente = Notification::Pendiente.find_by!(solicitud_id: solicitud)
    assert_equal "encuesta_satisfaccion", pendiente.notificacion
    assert_equal({ "curso" => "Excel básico", "link_encuesta" => "https://ejemplo.test/encuesta" }, pendiente.datos)
  end

  test "72: el aviso de cumpleaños va a toda la empresa, con los nombres y las fotos de quienes cumplen" do
    solicitud = Personas::AvisarCumpleanos.ejecutar(empresa_id: 1)

    pendientes = Notification::Pendiente.where(solicitud_id: solicitud).order(:usuario_id)
    assert_equal Usuario.where(empresa_id: 1).order(:id).ids, pendientes.map(&:usuario_id)
    assert_equal "saludo_cumpleanos", pendientes.first.notificacion
    assert_equal({ "fecha" => Date.current.strftime("%d-%m-%Y"), "nombres" => "Ana Soto y Bruno Díaz",
                   "cumpleaneros" => [{ "nombre" => "Ana Soto", "foto" => "/personas/ana-soto.svg" },
                                      { "nombre" => "Bruno Díaz", "foto" => "/personas/bruno-diaz.svg" }] },
                 pendientes.first.datos)
  end

  test "72: la fecha es la de Chile, y con tres cumpleañeros los nombres van con comas" do
    travel_to Time.utc(2027, 1, 1, 1, 0) # en Chile todavía es 31 de diciembre de 2026
    Usuario.where(id: [1, 2, 8]).update_all(nacimiento: Date.new(1990, 12, 31))
    solicitud = Personas::AvisarCumpleanos.ejecutar(empresa_id: 1)

    datos = Notification::Pendiente.find_by!(solicitud_id: solicitud).datos
    assert_equal "31-12-2026", datos["fecha"]
    assert_equal "Ana Soto, Bruno Díaz y Hugo Pinto (sin correo)", datos["nombres"]
    assert_equal "/personas/sin-foto.svg", datos["cumpleaneros"].last["foto"], "sin foto va la de respaldo"
  end

  test "72: si hoy nadie está de cumpleaños, la acción lo dice y no envía nada" do
    Usuario.update_all(nacimiento: Date.current - 1)

    error = assert_raises(Personas::AvisarCumpleanos::Invalida) { Personas::AvisarCumpleanos.ejecutar(empresa_id: 1) }
    assert_equal "Hoy no hay cumpleaños en Andes Capacitación", error.message
    assert_equal [0, 0, 0], conteos_de_send
  end

  test "72: avisar dos veces el mismo día deja el segundo como duplicado" do
    Personas::AvisarCumpleanos.ejecutar(empresa_id: 1)
    segunda = Personas::AvisarCumpleanos.ejecutar(empresa_id: 1)

    assert_equal 8, Notification::Pendiente.count
    assert_equal ["duplicada"], Notification::Auditoria.where(solicitud_id: segunda).pluck(:evento).uniq
  end
end
