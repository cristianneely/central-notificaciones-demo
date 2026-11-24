# Notificación del módulo de personas: el aviso de cumpleaños. Va a toda la empresa, una
# vez al día, con el nombre y la foto de cada persona que está de cumpleaños. Los nombres
# del título y del resumen salen de la misma lista: la central los escribe.
class SaludoCumpleanos < Notification
  criticidad  :opcional
  datos       :fecha, :cumpleaneros
  unica_por   :fecha

  contenido do
    titulo    "Cumpleaños de hoy: {cumpleaneros}"
    resumen   "Hoy celebramos a {cumpleaneros}. ¡No olvides saludar!"
    imagen    "/cumpleanos.svg", alt: "Ilustración de cumpleaños"
    personas  "{cumpleaneros}"
    destacado "¡Que lo pasen increíble!"
  end
end
