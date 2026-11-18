# Notificación del módulo de cursos: pedir la opinión sobre un curso.
class EncuestaSatisfaccion < Notification
  criticidad  :opcional
  datos       :curso, :link_encuesta
  unica_por   :curso
  contenido   titulo: "¿Qué te pareció {curso}?",
              cuerpo: "Cuéntanos tu experiencia en {curso}. Te toma dos minutos.",
              accion: { texto: "Responder encuesta", link: "{link_encuesta}" }
end
