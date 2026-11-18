# Notificación del módulo de certificados.
# El equipo declara aquí qué notificación existe; no dice por qué canal sale ni cuándo.
class CertificadoEmitido < Notification
  criticidad  :critica
  datos       :certificado_id, :curso, :link_certificado
  unica_por   :certificado_id
  contenido   titulo: "Tu certificado de {curso} está listo",
              cuerpo: "Felicitaciones, terminaste {curso}.",
              accion: { texto: "Descargar", link: "{link_certificado}" }
end
