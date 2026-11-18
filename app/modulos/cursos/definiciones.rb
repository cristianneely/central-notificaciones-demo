# Notificaciones del módulo de cursos.

Notification.define "recordatorio_curso",
  criticidad: :informativa,
  datos: [:curso, :fecha_limite, :link_curso],
  unica_por: [:curso, :fecha_limite],
  contenido: {
    titulo: "Recuerda terminar {curso}",
    cuerpo: "Tienes hasta el {fecha_limite} para completar {curso}.",
    accion: { texto: "Ir al curso", link: "{link_curso}" }
  }

Notification.define "encuesta_satisfaccion",
  criticidad: :opcional,
  datos: [:curso, :link_encuesta],
  unica_por: [:curso],
  contenido: {
    titulo: "¿Qué te pareció {curso}?",
    cuerpo: "Cuéntanos tu experiencia en {curso}. Te toma dos minutos.",
    accion: { texto: "Responder encuesta", link: "{link_encuesta}" }
  }
