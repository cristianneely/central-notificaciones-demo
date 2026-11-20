require "test_helper"

# API 1.1 del documento: una clase por notificación y el catálogo (R4 y R8).
# Cada definición se valida al registrarla; una inválida no entra al catálogo.
class CatalogoTest < ActiveSupport::TestCase
  # Una definición correcta, para cambiarle una sola cosa en cada prueba.
  VALIDA = {
    criticidad: :informativa,
    datos: [:curso, :link],
    unica_por: [:curso],
    contenido: proc do
      titulo  "Hola {curso}"
      resumen "Texto sobre {curso}."
      boton   "Ir", link: "{link}"
    end
  }.freeze

  setup { @catalogo = Notification::Catalogo.new }

  # Arma una clase de notificación con nombre, como la escribiría un equipo. Cada clave
  # es una declaración: `criticidad :critica`, `datos :curso, :link`, etc.
  def clase(nombre = "DePrueba", **campos)
    nueva = Class.new(Notification)
    Module.new.const_set(nombre, nueva)
    campos.each do |campo, valor|
      case campo
      when :datos, :unica_por then nueva.public_send(campo, *valor)
      # El contenido se declara con un bloque; un Hash es la forma antigua, que se rechaza.
      when :contenido then valor.is_a?(Proc) ? nueva.contenido(&valor) : nueva.contenido(**valor)
      else nueva.public_send(campo, valor)
      end
    end
    nueva
  end

  # Registra "de_prueba" con los cambios pedidos y devuelve la lista de errores.
  def errores_con(**cambios)
    error = assert_raises(Notification::DefinicionInvalida) do
      @catalogo.registrar(clase(**VALIDA.merge(cambios)))
    end
    error.errores
  end

  test "1: catálogo válido, con las cinco definiciones, su criticidad y su versión" do
    catalogo = Notification.catalogo

    assert_equal %w[certificado_emitido encuesta_satisfaccion recordatorio_curso saludo_cumpleanos
                    solicitud_vacaciones], catalogo.nombres
    assert_equal :critica, catalogo.buscar("certificado_emitido").criticidad
    assert_equal :informativa, catalogo.buscar("recordatorio_curso").criticidad
    assert_equal :opcional, catalogo.buscar("encuesta_satisfaccion").criticidad
    assert_equal :opcional, catalogo.buscar("saludo_cumpleanos").criticidad
    catalogo.todas.each do |definicion|
      assert_match(/\A[0-9a-f]{8}\z/, definicion.version)
    end
  end

  test "57: la solicitud de vacaciones es crítica, única por solicitud y trae lista y botón" do
    definicion = Notification.catalogo.buscar("solicitud_vacaciones")

    assert_equal :critica, definicion.criticidad
    assert_equal %i[solicitud_id solicitante desde hasta dias_habiles link_solicitud], definicion.datos
    assert_equal [:solicitud_id], definicion.unica_por
    assert_equal %i[titulo resumen parrafo lista boton], definicion.contenido.map { |pieza| pieza[:tipo] }
    assert_equal ["Desde: {desde}", "Hasta: {hasta}", "Días hábiles: {dias_habiles}"], definicion.contenido[3][:items]
    assert_equal({ tipo: :boton, texto: "Revisar solicitud", link: "{link_solicitud}" }, definicion.contenido.last)
  end

  test "57: el saludo de cumpleaños trae un destacado y una imagen propia de la demo" do
    piezas = Notification.catalogo.buscar("saludo_cumpleanos").contenido

    assert_equal %i[titulo resumen parrafo destacado imagen], piezas.map { |pieza| pieza[:tipo] }
    imagen = piezas.last
    assert_equal "/tarjeta-cumpleanos.svg", imagen[:url]
    assert Rails.root.join("public/tarjeta-cumpleanos.svg").exist?, "la tarjeta vive en public/"
  end

  test "1: el identificador sale del nombre de la clase" do
    assert_equal "certificado_emitido", CertificadoEmitido.identificador
    assert_equal CertificadoEmitido, Notification.catalogo.buscar("certificado_emitido").clase
    assert_equal "de_prueba", clase("DePrueba").identificador
  end

  test "1: la definición guarda lo declarado" do
    definicion = Notification.catalogo.buscar("certificado_emitido")

    assert_equal [:certificado_id, :curso, :link_certificado], definicion.datos
    assert_equal [:certificado_id], definicion.unica_por
    assert_equal [
      { tipo: :titulo, texto: "Tu certificado de {curso} está listo" },
      { tipo: :resumen, texto: "Terminaste {curso}. Descarga tu certificado." },
      { tipo: :parrafo, texto: "Felicitaciones, terminaste {curso}." },
      { tipo: :boton, texto: "Descargar", link: "{link_certificado}" }
    ], definicion.contenido
    assert_equal 0, definicion.prioridad
    assert definicion.critica?
  end

  test "1: la versión cambia cuando cambia el contenido" do
    una = @catalogo.registrar(clase("Una", **VALIDA))
    otra = @catalogo.registrar(clase("Otra", **VALIDA.merge(contenido: proc { titulo "Otro"; resumen "Texto sobre {curso}." })))
    igual = @catalogo.registrar(clase("Igual", **VALIDA))

    assert_not_equal una.version, otra.version
    assert_equal una.version, igual.version
  end

  test "2: una definición inválida informa todos sus errores juntos y no se registra" do
    mal_escrita = clase("MalEscrita", datos: [:curso],
                                      contenido: proc { titulo "Hola {dato_inexistente}"; resumen "x" },
                                      canales: [:email])
    error = assert_raises(Notification::DefinicionInvalida) { @catalogo.registrar(mal_escrita) }

    assert_equal [
      "criticidad debe ser :critica, :informativa u :opcional",
      "unica_por es obligatorio",
      "el contenido usa un dato no declarado: dato_inexistente",
      "clave no permitida: canales"
    ], error.errores
    assert_includes error.message, "mal_escrita"
    assert_nil @catalogo.buscar("mal_escrita")
  end

  test "2: una clase vacía informa todo lo que le falta" do
    error = assert_raises(Notification::DefinicionInvalida) { @catalogo.registrar(clase("Vacia")) }

    assert_equal [
      "criticidad debe ser :critica, :informativa u :opcional",
      "datos debe ser una lista de nombres sin repetir",
      "unica_por es obligatorio",
      "contenido necesita titulo y resumen"
    ], error.errores
  end

  test "2b: nombre con formato inválido" do
    assert_equal ["nombre inválido"], Notification::ValidadorDefinicion.errores(
      "Mal Nombre", VALIDA.merge(contenido: Notification::Contenido.declarar(&VALIDA[:contenido])))
  end

  test "2b: una clase sin nombre" do
    sin_nombre = Class.new(Notification) { criticidad :opcional }
    error = assert_raises(Notification::DefinicionInvalida) { @catalogo.registrar(sin_nombre) }

    assert_includes error.errores, "nombre inválido"
  end

  test "2b: criticidad que no es una de las tres" do
    assert_equal ["criticidad debe ser :critica, :informativa u :opcional"],
                 errores_con(criticidad: :urgente)
  end

  test "2b: datos repetidos" do
    assert_includes errores_con(datos: [:curso, :curso, :link]),
                    "datos debe ser una lista de nombres sin repetir"
  end

  test "2b: datos que no son nombres" do
    assert_includes errores_con(datos: ["curso", "link"]),
                    "datos debe ser una lista de nombres sin repetir"
  end

  test "2b: unica_por vacío" do
    assert_equal ["unica_por es obligatorio"], errores_con(unica_por: [])
  end

  test "2b: unica_por nombra un dato no declarado" do
    assert_equal ["unica_por usa un dato no declarado: otro"], errores_con(unica_por: [:otro])
  end

  test "2b: contenido sin titulo" do
    assert_equal ["contenido necesita titulo y resumen"], errores_con(contenido: proc { resumen "Texto" })
  end

  test "2b: contenido sin resumen" do
    assert_equal ["contenido necesita titulo y resumen"], errores_con(contenido: proc { titulo "Hola" })
  end

  test "2b: titulo o resumen repetidos" do
    assert_equal ["titulo y resumen van una sola vez"],
                 errores_con(contenido: proc { titulo "Hola"; titulo "Otra vez"; resumen "Texto" })
  end

  test "2b: una pieza fuera del vocabulario" do
    assert_equal ["pieza no permitida: video"],
                 errores_con(contenido: proc { titulo "Hola"; resumen "Texto"; video "https://ejemplo.test/v" })
  end

  test "2b: una pieza de texto sin texto" do
    assert_equal ["parrafo necesita un texto"],
                 errores_con(contenido: proc { titulo "Hola"; resumen "Texto"; parrafo "  " })
  end

  test "2b: boton incompleto" do
    assert_equal ["boton necesita texto y link"],
                 errores_con(contenido: proc { titulo "Hola"; resumen "Texto"; boton "Ir" })
  end

  test "2b: imagen sin texto alternativo" do
    assert_equal ["imagen necesita url y alt"],
                 errores_con(contenido: proc { titulo "Hola"; resumen "Texto"; imagen "https://ejemplo.test/i.png" })
  end

  test "2b: lista vacía" do
    assert_equal ["lista necesita al menos un elemento"],
                 errores_con(contenido: proc { titulo "Hola"; resumen "Texto"; lista })
  end

  test "2b: marcador de un dato no declarado en el link del boton, en una lista y en una imagen" do
    contenido = proc do
      titulo  "Hola"
      resumen "Texto"
      lista   "Uno: {dato_lista}"
      imagen  "{dato_imagen}", alt: "Foto de {dato_alt}"
      boton   "Ir", link: "{otro_link}"
    end

    assert_equal %w[dato_lista dato_imagen dato_alt otro_link].map { |dato| "el contenido usa un dato no declarado: #{dato}" },
                 errores_con(contenido: contenido)
  end

  test "43: la forma antigua del contenido, con claves, se rechaza" do
    assert_equal ["contenido se declara con un bloque de piezas"],
                 errores_con(contenido: { titulo: "Hola", cuerpo: "Texto" })
  end

  test "43: un bloque de contenido vacío" do
    assert_equal ["contenido necesita titulo y resumen"], errores_con(contenido: proc {})
  end

  test "3: nombre repetido" do
    @catalogo.registrar(clase(**VALIDA))

    assert_equal ["ya existe una definición con ese nombre"], errores_con
    assert_equal ["de_prueba"], @catalogo.nombres
  end
end
