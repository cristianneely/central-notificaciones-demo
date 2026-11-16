module Api
  # La puerta API de la acción "emitir certificado": POST /api/certificados.
  # Llama a la misma acción que la pantalla. No pide credenciales (es una demo) y no
  # acepta los interruptores de demo.
  class CertificadosController < ActionController::API
    # Todo lo que entra por aquí queda anotado con origen "api".
    before_action { Notification::Contexto.origen = "api" }

    rescue_from ActionDispatch::Http::Parameters::ParseError do
      render json: { error: "JSON inválido" }, status: :bad_request
    end

    def create
      resultado = Certificados::EmitirCertificado.ejecutar(
        empresa_id: params[:empresa_id],
        usuario_id: params[:usuario_id],
        curso: params[:curso]
      )
      render json: { certificado_id: resultado.certificado.id, solicitud_id: resultado.solicitud_id },
             status: :created
    rescue Certificados::EmitirCertificado::Invalida => error
      render json: { error: error.message }, status: :unprocessable_content
    end
  end
end
