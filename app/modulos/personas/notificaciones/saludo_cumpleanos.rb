# Notificación del módulo de personas: el aviso de cumpleaños. Va a toda la empresa, una
# vez al día, con el nombre y la foto de cada persona que está de cumpleaños.
class SaludoCumpleanos < Notification
  criticidad  :opcional
  datos       :fecha, :nombres, :cumpleaneros
  unica_por   :fecha

  contenido do
    titulo    "Cumpleaños de hoy: {nombres}"
    resumen   "Hoy celebramos a {nombres}. ¡No olvides saludar!"
    personas  "{cumpleaneros}"
    destacado "¡Que lo pasen increíble!"
  end
end
