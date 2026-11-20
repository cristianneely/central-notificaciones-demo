# Notificación del módulo de certificados.
# El equipo declara aquí qué notificación existe; no dice por qué canal sale ni cuándo.
class CertificadoEmitido < Notification
  criticidad  :critica
  datos       :certificado_id, :curso, :imagen_curso, :link_certificado
  unica_por   :certificado_id

  contenido do
    titulo  "Tu certificado de {curso} está listo"
    resumen "Terminaste {curso}. Descarga tu certificado."
    imagen  "{imagen_curso}", alt: "Portada de {curso}"
    parrafo "Felicitaciones, terminaste {curso}."
    boton   "Descargar", link: "{link_certificado}"
  end
end
