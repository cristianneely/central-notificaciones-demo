# Notificación del módulo de cursos: pedir la opinión sobre un curso.
class EncuestaSatisfaccion < Notification
  criticidad  :opcional
  datos       :curso, :link_encuesta
  unica_por   :curso

  contenido do
    titulo  "¿Qué te pareció {curso}?"
    resumen "Cuéntanos tu experiencia en {curso}."
    parrafo "Cuéntanos tu experiencia en {curso}. Te toma dos minutos."
    boton   "Responder encuesta", link: "{link_encuesta}"
  end
end
