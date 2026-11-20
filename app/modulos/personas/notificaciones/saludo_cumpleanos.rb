# Notificación del módulo de personas: el saludo de cumpleaños. Una vez al año.
class SaludoCumpleanos < Notification
  criticidad  :opcional
  datos       :nombre, :anio
  unica_por   :anio

  contenido do
    titulo  "¡Feliz cumpleaños, {nombre}!"
    resumen "Todo el equipo te desea un gran día."
    parrafo   "Todo el equipo te desea un gran día."
    destacado "¡Que lo pases increíble, {nombre}!"
    imagen    "/tarjeta-cumpleanos.svg", alt: "Tarjeta de saludo de cumpleaños"
  end
end
