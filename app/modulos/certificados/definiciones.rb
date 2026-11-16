# Notificaciones del módulo de certificados.
# Un equipo declara aquí qué notificación existe; no dice por qué canal sale ni cuándo.

Notification.define "certificado_emitido",
  importancia: :critica,
  datos: [:certificado_id, :curso, :link_certificado],
  unica_por: [:certificado_id],
  contenido: {
    titulo: "Tu certificado de {curso} está listo",
    cuerpo: "Felicitaciones, terminaste {curso}.",
    accion: { texto: "Descargar", link: "{link_certificado}" }
  }
