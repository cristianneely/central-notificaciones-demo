# Notificación del módulo de cursos: recordar a una persona que termine un curso.
class RecordatorioCurso < Notification
  criticidad  :informativa
  datos       :curso, :fecha_limite, :link_curso
  unica_por   :curso, :fecha_limite
  contenido   titulo: "Recuerda terminar {curso}",
              cuerpo: "Tienes hasta el {fecha_limite} para completar {curso}.",
              accion: { texto: "Ir al curso", link: "{link_curso}" }
end
