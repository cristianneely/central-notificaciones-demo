# Atajos que comparten las pruebas de la central.
module AyudasCentral
  # Empresas, personas y políticas de la siembra (sin el historial de ejemplo).
  def sembrar
    Demo::Siembra.datos_base
  end

  # Busca una persona por una parte de su nombre: persona("(rebota)").
  def persona(texto, empresa_id: nil)
    personas = Usuario.where("nombre LIKE ?", "%#{texto}%")
    personas = personas.where(empresa_id: empresa_id) if empresa_id
    personas.order(:id).first!
  end

  # Los eventos de una solicitud en el orden en que se anotaron: ["recibida", "enviada"].
  def eventos(solicitud_id, usuario_id = nil)
    recorrido(solicitud_id, usuario_id).map(&:evento)
  end

  def recorrido(solicitud_id, usuario_id = nil)
    filas = Notification::Auditoria.where(solicitud_id: solicitud_id)
    filas = filas.where(usuario_id: usuario_id) if usuario_id
    filas.order(:id).to_a
  end

  # Llama a send() directo con un certificado. Las pruebas de la central no pasan por
  # las acciones de negocio, que tienen sus propias pruebas.
  def enviar_certificado(usuario, certificado_id: 789, curso: "Excel avanzado",
                         link: "https://ejemplo.test/certificados/789")
    Notification.send "certificado_emitido",
      empresa: usuario.empresa_id,
      destinatarios: [usuario.id],
      datos: { certificado_id: certificado_id, curso: curso, link_certificado: link }
  end

  def enviar_recordatorio(usuario, curso: "Excel básico", fecha_limite: "22-11-2026")
    Notification.send "recordatorio_curso",
      empresa: usuario.empresa_id,
      destinatarios: [usuario.id],
      datos: { curso: curso, fecha_limite: fecha_limite, link_curso: "https://ejemplo.test/cursos" }
  end

  # Cuántas filas hay en las tres tablas que escribe send().
  def conteos_de_send
    [Notification::ClaveUnica.count, Notification::Pendiente.count, Notification::Auditoria.count]
  end
end
