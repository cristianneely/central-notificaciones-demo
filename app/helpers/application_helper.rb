module ApplicationHelper
  # Fecha y hora en hora de Chile (la base guarda en UTC).
  def hora(momento)
    momento.in_time_zone.strftime("%d-%m %H:%M:%S")
  end

  # Etiqueta de color para la importancia: crítica, informativa u opcional.
  def etiqueta_importancia(importancia)
    tag.span(importancia, class: "etiqueta importancia-#{importancia}")
  end

  # El nombre de una persona a partir de su id; si el id no existe, lo dice.
  def nombre_persona(usuario_id)
    @nombres_personas.fetch(usuario_id, "usuario ##{usuario_id} (no existe)")
  end

  # El detalle de una fila de la auditoría, como texto.
  def detalle_como_texto(detalle)
    detalle.blank? ? "" : JSON.generate(detalle)
  end

  # Un evento del recorrido, con su motivo legible si lo tiene.
  def evento_con_motivo(fila)
    fila.motivo.present? ? "#{fila.evento} (#{Notification::Historial.motivo_legible(fila.motivo)})" : fila.evento
  end

  # Clase de color según cómo terminó la solicitud.
  def clase_estado(estado)
    case estado
    when /\AEntregada/ then "estado-ok"
    when /\A(Pendiente|En espera|Enviada)/ then "estado-en-curso"
    else "estado-no"
    end
  end
end
