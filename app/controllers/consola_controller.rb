# Consola de demo (/). Desde aquí se disparan las acciones de negocio y se ve qué hace
# la central con cada notificación. Los botones de acciones van a AccionesController.
class ConsolaController < ApplicationController
  PENDIENTES_VISIBLES = 50

  before_action :cargar_seleccion

  def index
    cargar_listas
  end

  # Las listas solas, sin el marco de la página: la consola las vuelve a pedir cada 2 s.
  def listas
    cargar_listas
    render partial: "listas"
  end

  # Interruptor del proveedor simulado. Encenderlo no le avisa a la central: ella lo
  # descubre en su próximo intento.
  def proveedor
    if params[:encender] == "1"
      Notification::Proveedores::Simulado.encender
    else
      Notification::Proveedores::Simulado.apagar
    end
    volver
  end

  # "Intentar apagar lo crítico": existe solo para mostrar el rechazo (R6).
  def apagar_critico
    return volver(error: "No hay empresas sembradas.") unless @empresa

    Notification::Politicas.guardar(empresa_id: @empresa.id, importancia: "critica", canal: "email",
                                    habilitado: false)
    volver resultado: "Política guardada."
  rescue Notification::PoliticaInvalida => error
    volver error: "Rechazado: #{error.message}"
  end

  def reiniciar
    Demo::Reinicio.ejecutar
    redirect_to root_path, flash: { resultado: "Demo reiniciada: la base volvió a los datos semilla." }
  end

  private

  # La empresa, la persona y el curso elegidos viajan en la dirección de la página.
  def cargar_seleccion
    @empresas = Empresa.order(:id).to_a
    @empresa = @empresas.find { |empresa| empresa.id == params[:empresa_id].to_s.to_i } || @empresas.first
    @personas = @empresa ? @empresa.usuarios.order(:id).to_a : []
    @persona = @personas.find { |persona| persona.id == params[:usuario_id].to_s.to_i } || @personas.first
    @curso = Cursos::LISTA.include?(params[:curso]) ? params[:curso] : Cursos::LISTA.first
  end

  def cargar_listas
    ahora = Time.current
    @proveedor_encendido = Notification::Proveedores::Simulado.encendido?
    @canal = Notification::EstadoCanal.para("email")
    @segundos_para_reintentar = @canal.segundos_para_reintentar(ahora)
    @certificados = @empresa ? Certificado.where(empresa_id: @empresa.id).count : 0

    # Pendientes de todas las empresas, en el orden en que el despachador los tomaría.
    # Se muestran los primeros 50; el total va aparte.
    @pendientes = Notification::Pendiente.en_orden.limit(PENDIENTES_VISIBLES).to_a
    @total_pendientes = Notification::Pendiente.count
    @solicitudes = @empresa ? Notification::Historial.filas(empresa_id: @empresa.id, limite: 20) : []
    @bandeja = Notification::Proveedores::CorreoSimulado.order(id: :desc).limit(20).to_a

    @nombres_empresas = @empresas.to_h { |empresa| [empresa.id, empresa.nombre] }
    @nombres_personas = Usuario.pluck(:id, :nombre).to_h
  end

  def volver(mensajes = {})
    redirect_to root_path(params.permit(:empresa_id, :usuario_id, :curso).to_h), flash: mensajes
  end
end
