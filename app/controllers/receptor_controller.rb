# La puerta del receptor: POST /receptor/proveedor. Por aquí el proveedor de correo
# avisa en qué terminó un envío. Solo traduce la petición; la lógica es de la central.
class ReceptorController < ActionController::API
  rescue_from ActionDispatch::Http::Parameters::ParseError do
    render json: { error: "JSON inválido" }, status: :bad_request
  end

  def proveedor
    Notification::Receptor.recibir(
      solicitud_id: params[:solicitud_id],
      usuario_id: params[:usuario_id],
      id_proveedor: params[:id_proveedor],
      estado: params[:estado]
    )
    render json: { ok: true }
  rescue Notification::Receptor::EnvioDesconocido => error
    render json: { error: error.message }, status: :not_found
  rescue Notification::Receptor::AvisoInvalido => error
    render json: { error: error.message }, status: :unprocessable_content
  end
end
