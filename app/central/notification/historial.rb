module Notification
  # Lectura de la auditoría para las pantallas (R12): arma, a partir de las filas, una
  # línea por solicitud y persona con su estado final y su recorrido completo.
  # Siempre filtra por empresa: cada empresa ve solo lo suyo.
  module Historial
    Fila = Data.define(:solicitud_id, :usuario_id, :notificacion, :importancia, :estado, :recorrido, :creado_en)

    MOTIVOS = {
      "sin_contacto" => "sin contacto",
      "politica_cliente" => "política del cliente",
      "limite_frecuencia" => "límite de frecuencia",
      "proveedor_no_disponible" => "proveedor no disponible",
      "rechazado_por_proveedor" => "el proveedor rechazó el correo",
      "clave_repetida" => "clave repetida"
    }.freeze

    # De la más reciente a la más antigua. `desde` y `hasta` son fechas en hora de Chile,
    # inclusive.
    def self.filas(empresa_id:, usuario_id: nil, desde: nil, hasta: nil, limite: 200)
      filtradas = Auditoria.where(empresa_id: empresa_id)
      filtradas = filtradas.where(usuario_id: usuario_id) if usuario_id.present?
      filtradas = filtradas.where(creado_en: desde.in_time_zone.beginning_of_day..) if desde
      filtradas = filtradas.where(creado_en: ..hasta.in_time_zone.end_of_day) if hasta

      # Primero, cuáles solicitudes y personas entran (las más recientes); después, el
      # recorrido completo de cada una.
      pares = filtradas.group(:solicitud_id, :usuario_id)
                       .order(Arel.sql("MIN(id) DESC")).limit(limite) # por cuándo se pidió
                       .pluck(:solicitud_id, :usuario_id)
      recorridos = Auditoria.where(empresa_id: empresa_id, solicitud_id: pares.map(&:first)).order(:id)
                            .group_by { |fila| [fila.solicitud_id, fila.usuario_id] }

      pares.map do |par|
        recorrido = recorridos.fetch(par)
        primera = recorrido.first
        Fila.new(
          solicitud_id: primera.solicitud_id,
          usuario_id: primera.usuario_id,
          notificacion: primera.notificacion,
          importancia: primera.importancia,
          estado: estado(recorrido.last),
          recorrido: recorrido,
          creado_en: primera.creado_en
        )
      end
    end

    # El estado final que se muestra, según la última anotación del recorrido.
    def self.estado(ultima)
      case ultima.evento
      when "recibida" then "Pendiente"
      when "decision_enviar", "intento_fallido" then "En espera del proveedor"
      when "enviada" then "Enviada, sin confirmación"
      when "entregada" then "Entregada"
      when "rebotada" then "Rebotada"
      when "duplicada" then "Duplicada"
      when "no_enviada" then "No enviada: #{motivo_legible(ultima.motivo)}"
      when "retenida" then "Retenida: límite de frecuencia"
      when "fallo_definitivo" then "Falló: #{motivo_legible(ultima.motivo)}"
      else ultima.evento
      end
    end

    def self.motivo_legible(motivo)
      MOTIVOS.fetch(motivo, motivo.to_s)
    end
  end
end
