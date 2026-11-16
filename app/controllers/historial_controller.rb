# Historial (/historial): qué pasó con cada notificación de una empresa (R12).
class HistorialController < ApplicationController
  def index
    # La empresa es obligatoria: sin elegir, se muestra la primera.
    @empresas = Empresa.order(:id).to_a
    @empresa = @empresas.find { |empresa| empresa.id == params[:empresa_id].to_s.to_i } || @empresas.first
    @personas = @empresa ? @empresa.usuarios.order(:id).to_a : []
    @persona = @personas.find { |persona| persona.id == params[:usuario_id].to_s.to_i }

    # Por defecto, los últimos 7 días (en hora de Chile).
    hoy = Date.current
    @desde = fecha(params[:desde]) || hoy - 7
    @hasta = fecha(params[:hasta]) || hoy

    @filas = []
    if @empresa
      @filas = Notification::Historial.filas(empresa_id: @empresa.id, usuario_id: @persona&.id,
                                             desde: @desde, hasta: @hasta)
    end
    @nombres_personas = Usuario.pluck(:id, :nombre).to_h
  end

  private

  # Una fecha escrita como AAAA-MM-DD; si viene vacía o mal escrita, no se usa.
  def fecha(texto)
    Date.iso8601(texto.to_s)
  rescue ArgumentError # incluye una fecha mal escrita o un texto demasiado largo
    nil
  end
end
