class Notification
  # Lo que responde un proveedor cuando se le entrega un mensaje. Solo hay tres casos:
  #   aceptado       — lo recibió y devolvió su id.
  #   rechazado      — rechazó ese mensaje en particular (por ejemplo, dirección inválida).
  #   sin_respuesta  — no contestó: el proveedor está caído.
  Resultado = Data.define(:estado, :id_proveedor, :mensaje) do
    def self.aceptado(id_proveedor)
      new(estado: :aceptado, id_proveedor: id_proveedor, mensaje: nil)
    end

    def self.rechazado(mensaje)
      new(estado: :rechazado, id_proveedor: nil, mensaje: mensaje)
    end

    def self.sin_respuesta
      new(estado: :sin_respuesta, id_proveedor: nil, mensaje: nil)
    end

    def aceptado? = estado == :aceptado
    def rechazado? = estado == :rechazado
    def sin_respuesta? = estado == :sin_respuesta
  end
end
