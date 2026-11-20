# Notificación del módulo de cursos: recordar a una persona que termine un curso.
class RecordatorioCurso < Notification
  criticidad  :informativa
  datos       :curso, :fecha_limite, :link_curso
  unica_por   :curso, :fecha_limite

  contenido do
    titulo  "Recuerda terminar {curso}"
    resumen "Tienes hasta el {fecha_limite} para completar {curso}."
    parrafo "Tienes hasta el {fecha_limite} para completar {curso}."
    boton   "Ir al curso", link: "{link_curso}"
  end
end
