# Simulador (/simulador): cómo llega una misma notificación por cada canal. Solo lee:
# no llama a send() ni escribe en la base.
class SimuladorController < ApplicationController
  def index
    datos = params[:datos].respond_to?(:to_unsafe_h) ? params[:datos].to_unsafe_h : {}
    @simulacion = Demo::Simulador.simular(params[:notificacion].to_s, datos, params[:para].to_s)
    @notificaciones = Demo::Simulador::NOTIFICACIONES
  end
end
