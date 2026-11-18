class Notification
  # El receptor: recibe del proveedor el aviso de en qué terminó un envío (entregado o
  # rebotado) y lo anota en la auditoría.
  module Receptor
    class AvisoInvalido < StandardError; end
    class EnvioDesconocido < StandardError; end

    # Estado que informa el proveedor → evento que se anota.
    EVENTOS = { "entregado" => "entregada", "rebotado" => "rebotada" }.freeze

    # Devuelve :anotado, o :ya_anotado si ese envío ya tenía estado final (un aviso
    # repetido no agrega nada).
    def self.recibir(solicitud_id:, usuario_id:, id_proveedor:, estado:)
      # Lo que manda el proveedor se lee como texto: un campo con otra forma no calza con
      # ningún envío, pero tampoco rompe el receptor.
      solicitud_id, usuario_id, id_proveedor, estado =
        [solicitud_id, usuario_id, id_proveedor, estado].map { |valor| valor.to_s.strip }

      { solicitud_id: solicitud_id, usuario_id: usuario_id, id_proveedor: id_proveedor,
        estado: estado }.each do |campo, valor|
        raise AvisoInvalido, "falta #{campo}" if valor.empty?
      end
      evento = EVENTOS[estado] or raise AvisoInvalido, "estado debe ser entregado o rebotado"

      # El aviso tiene que calzar con un envío que la central haya hecho de verdad.
      recorrido = usuario_id.match?(/\A\d{1,18}\z/) ? Auditoria.recorrido(solicitud_id, usuario_id.to_i).to_a : []
      enviada = recorrido.find do |fila|
        fila.evento == "enviada" && fila.detalle["id_proveedor"] == id_proveedor
      end
      raise EnvioDesconocido, "no existe un envío con esos datos" unless enviada

      return :ya_anotado if recorrido.any? { |fila| EVENTOS.value?(fila.evento) }

      Auditoria.anotar(enviada, evento, canal: enviada.canal, detalle: { id_proveedor: id_proveedor })
      :anotado
    end
  end
end
