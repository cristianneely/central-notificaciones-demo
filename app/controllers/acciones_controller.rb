# La puerta web de las acciones de negocio: los botones de la consola. Solo llama a las
# acciones; nunca a send() (R9).
class AccionesController < ApplicationController
  # Un pedido que la acción o la central rechazan vuelve a la consola con su mensaje.
  rescue_from Certificados::EmitirCertificado::Invalida, Notification::SolicitudInvalida do |error|
    volver error: error.message
  end

  def emitir_certificado
    resultado = Certificados::EmitirCertificado.ejecutar(
      **pedido,
      llamar_dos_veces: params[:llamar_dos_veces] == "1",
      fallar_a_la_mitad: params[:fallar_a_la_mitad] == "1"
    )
    volver resultado: "Certificado ##{resultado.certificado.id} emitido. " \
                      "Solicitud #{resultado.solicitud_id.first(8)}."
  rescue Certificados::EmitirCertificado::FallaSimulada
    volver error: "La acción falló a la mitad: no se guardó el certificado ni la notificación."
  end

  def recordatorio
    ejecutada Cursos::EnviarRecordatorio.ejecutar(**pedido)
  end

  def encuesta
    ejecutada Cursos::EnviarEncuesta.ejecutar(**pedido)
  end

  def cumpleanos
    ejecutada Personas::SaludarCumpleanos.ejecutar(**pedido.except(:curso))
  end

  private

  # Lo que llega del formulario, como texto. Un parámetro con forma rara (un objeto en
  # vez de un valor) termina como un id que no existe, no como un error.
  def pedido
    { empresa_id: params[:empresa_id].to_s, usuario_id: params[:usuario_id].to_s, curso: params[:curso].to_s }
  end

  def ejecutada(solicitud_id)
    volver resultado: "Acción ejecutada. Solicitud #{solicitud_id.first(8)}."
  end

  # Vuelve a la consola conservando la empresa, la persona y el curso elegidos.
  def volver(mensajes)
    redirect_to consola_path(params.permit(:empresa_id, :usuario_id, :curso).to_h), flash: mensajes
  end
end
