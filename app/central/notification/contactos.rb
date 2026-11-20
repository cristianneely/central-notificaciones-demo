class Notification
  # Los datos de contacto de una persona. Cada canal declara cuál necesita (`contacto`) y
  # el despachador lo busca aquí, así que ningún canal ni ningún equipo maneja direcciones.
  module Contactos
    # Dato que pide un canal → columna del usuario donde está. Hoy las personas solo
    # tienen correo; un canal que pida otro dato (un teléfono) agrega aquí su línea.
    COLUMNAS = { correo: :email }.freeze

    # El dato, sin espacios, o nil si la persona no lo tiene o la central no lo conoce.
    def self.buscar(usuario, dato)
      columna = COLUMNAS[dato] or return nil

      usuario.public_send(columna).to_s.strip.presence
    end
  end
end
