# Notificaciones del módulo de personas.

Notification.define "saludo_cumpleanos",
  criticidad: :opcional,
  datos: [:nombre, :anio],
  unica_por: [:anio],
  contenido: {
    titulo: "¡Feliz cumpleaños, {nombre}!",
    cuerpo: "Todo el equipo te desea un gran día."
  }
