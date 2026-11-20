class Notification
  # Por qué puerta entró la petición que se está atendiendo: "web", "api" o "interno"
  # (sin petición: pruebas, consola de Rails, siembra). Las puertas lo anotan aquí y
  # send() lo lee, sin que haga falta pasarlo como parámetro. Rails lo limpia solo al
  # terminar cada petición.
  class Contexto < ActiveSupport::CurrentAttributes
    attribute :origen, default: "interno"
  end
end
