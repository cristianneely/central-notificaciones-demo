# Notificación del módulo de vacaciones: avisa a la jefatura que alguien pidió
# vacaciones. Es crítica porque pide una acción: el límite de frecuencia nunca la descarta.
class SolicitudVacaciones < Notification
  criticidad  :critica
  datos       :solicitud_id, :solicitante, :desde, :hasta, :dias_habiles, :link_solicitud
  unica_por   :solicitud_id

  contenido do
    titulo  "{solicitante} pidió vacaciones"
    resumen "{solicitante} pidió vacaciones del {desde} al {hasta}."
    imagen  "/vacaciones.svg", alt: "Ilustración de vacaciones"
    parrafo "{solicitante} envió una solicitud de vacaciones y espera tu respuesta."
    lista   "Desde: {desde}", "Hasta: {hasta}", "Días hábiles: {dias_habiles}"
    boton   "Revisar solicitud", link: "{link_solicitud}"
  end
end
