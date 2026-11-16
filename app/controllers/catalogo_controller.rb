# Catálogo (/catalogo). Muestra las definiciones y permite probar a mano las dos APIs.
class CatalogoController < ApplicationController
  before_action :preparar

  def index
  end

  # "Probar una definición inválida": valida un ejemplo mal escrito y muestra sus
  # errores. No lo registra.
  def definicion_invalida
    @errores_definicion = Demo::DefinicionInvalida.errores
    render :index
  end

  # Formulario "Probar send()". El controlador no llama a send(): llama a una acción de
  # laboratorio, que es la que lo hace (R9).
  def probar_send
    @solicitud = Demo::ProbarSend.ejecutar(
      notificacion: @notificacion,
      empresa_id: @empresa_id,
      destinatarios_texto: @destinatarios,
      datos_texto: @datos
    )
    render :index
  rescue Demo::ProbarSend::Invalida, Notification::SolicitudInvalida => error
    @error_send = error.message
    render :index
  end

  private

  def preparar
    @definiciones = Notification.catalogo.todas
    @empresas = Empresa.order(:id).to_a
    # La primera persona de cada empresa, para proponer un destinatario.
    @primera_persona = Usuario.group(:empresa_id).minimum(:id)

    # Lo que muestra el formulario: lo que se envió o, la primera vez, valores de ejemplo.
    @notificaciones = @definiciones.map(&:nombre) + ["una_que_no_existe"]
    @notificacion = (params[:notificacion].presence || @notificaciones.first).to_s
    @empresa_id = (params[:empresa_id].presence || @empresas.first&.id).to_s
    @destinatarios = (params[:destinatarios] || @primera_persona[@empresa_id.to_i]).to_s
    @datos = (params[:datos] || ejemplo_como_texto(@notificacion)).to_s
    @ejemplos = @notificaciones.to_h { |nombre| [nombre, ejemplo_como_texto(nombre)] }
  end

  def ejemplo_como_texto(notificacion)
    JSON.pretty_generate(Demo::ProbarSend.datos_de_ejemplo(notificacion))
  end
end
