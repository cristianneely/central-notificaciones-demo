require "digest"

module Notification
  # Una definición ya validada: lo que un equipo declaró con Notification.define.
  # Es un valor de solo lectura; no se guarda en la base, vive en el catálogo.
  Definicion = Data.define(:nombre, :criticidad, :datos, :unica_por, :contenido, :version) do
    # Arma la definición a partir de las opciones de define y le calcula la versión.
    def self.desde(nombre, opciones)
      contenido = opciones[:contenido]
      new(
        nombre: nombre,
        criticidad: opciones[:criticidad],
        datos: opciones[:datos],
        unica_por: opciones[:unica_por],
        contenido: contenido,
        version: version_de(contenido)
      )
    end

    # Versión del contenido: los primeros 8 caracteres del SHA-256 del contenido.
    # Si alguien cambia el texto, cambia la versión, y la auditoría sabe con cuál se envió.
    def self.version_de(contenido)
      Digest::SHA256.hexdigest(contenido.to_json)[0, 8]
    end

    # 0 crítica, 1 informativa, 2 opcional: el orden en que el despachador las toma.
    def prioridad
      Configuracion::PRIORIDADES.fetch(criticidad)
    end

    def critica?
      criticidad == :critica
    end
  end
end
