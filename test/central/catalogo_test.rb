require "test_helper"

# API 1.1 del documento: una clase por notificación y el catálogo (R4 y R8).
# Cada definición se valida al registrarla; una inválida no entra al catálogo.
class CatalogoTest < ActiveSupport::TestCase
  # Una definición correcta, para cambiarle una sola cosa en cada prueba.
  VALIDA = {
    criticidad: :informativa,
    datos: [:curso, :link],
    unica_por: [:curso],
    contenido: {
      titulo: "Hola {curso}",
      cuerpo: "Texto sobre {curso}.",
      accion: { texto: "Ir", link: "{link}" }
    }
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
      when :contenido then nueva.contenido(**valor)
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

  test "1: catálogo válido, con las cuatro definiciones, su criticidad y su versión" do
    catalogo = Notification.catalogo

    assert_equal %w[certificado_emitido encuesta_satisfaccion recordatorio_curso saludo_cumpleanos],
                 catalogo.nombres
    assert_equal :critica, catalogo.buscar("certificado_emitido").criticidad
    assert_equal :informativa, catalogo.buscar("recordatorio_curso").criticidad
    assert_equal :opcional, catalogo.buscar("encuesta_satisfaccion").criticidad
    assert_equal :opcional, catalogo.buscar("saludo_cumpleanos").criticidad
    catalogo.todas.each do |definicion|
      assert_match(/\A[0-9a-f]{8}\z/, definicion.version)
    end
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
    assert_equal "Tu certificado de {curso} está listo", definicion.contenido[:titulo]
    assert_equal 0, definicion.prioridad
    assert definicion.critica?
  end

  test "1: la versión cambia cuando cambia el contenido" do
    una = @catalogo.registrar(clase("Una", **VALIDA))
    otra = @catalogo.registrar(clase("Otra", **VALIDA.merge(contenido: { titulo: "Otro", cuerpo: "Texto" })))
    igual = @catalogo.registrar(clase("Igual", **VALIDA))

    assert_not_equal una.version, otra.version
    assert_equal una.version, igual.version
  end

  test "2: una definición inválida informa todos sus errores juntos y no se registra" do
    mal_escrita = clase("MalEscrita", datos: [:curso],
                                      contenido: { titulo: "Hola {dato_inexistente}", cuerpo: "x" },
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
      "contenido necesita titulo y cuerpo"
    ], error.errores
  end

  test "2b: nombre con formato inválido" do
    assert_equal ["nombre inválido"], Notification::ValidadorDefinicion.errores("Mal Nombre", VALIDA)
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
    assert_equal ["contenido necesita titulo y cuerpo"], errores_con(contenido: { cuerpo: "Texto" })
  end

  test "2b: contenido sin cuerpo" do
    assert_equal ["contenido necesita titulo y cuerpo"], errores_con(contenido: { titulo: "Hola" })
  end

  test "2b: accion incompleta" do
    assert_equal ["accion necesita texto y link"],
                 errores_con(contenido: { titulo: "Hola", cuerpo: "Texto", accion: { texto: "Ir" } })
  end

  test "2b: marcador de un dato no declarado en el link de la accion" do
    contenido = { titulo: "Hola", cuerpo: "Texto", accion: { texto: "Ir", link: "{otro_link}" } }

    assert_equal ["el contenido usa un dato no declarado: otro_link"], errores_con(contenido: contenido)
  end

  test "2b: clave no permitida dentro del contenido" do
    assert_equal ["clave no permitida: asunto"],
                 errores_con(contenido: { titulo: "Hola", cuerpo: "Texto", asunto: "x" })
  end

  test "3: nombre repetido" do
    @catalogo.registrar(clase(**VALIDA))

    assert_equal ["ya existe una definición con ese nombre"], errores_con
    assert_equal ["de_prueba"], @catalogo.nombres
  end
end
