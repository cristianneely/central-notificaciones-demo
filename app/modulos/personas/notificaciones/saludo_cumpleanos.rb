# Notificación del módulo de personas: el saludo de cumpleaños. Una vez al año.
class SaludoCumpleanos < Notification
  criticidad  :opcional
  datos       :nombre, :anio
  unica_por   :anio
  contenido   titulo: "¡Feliz cumpleaños, {nombre}!",
              cuerpo: "Todo el equipo te desea un gran día."
end
