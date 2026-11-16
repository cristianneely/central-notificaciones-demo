class ApplicationController < ActionController::Base
  # Todo lo que entra por una pantalla queda anotado con origen "web". La central lo lee
  # de este contexto; así no hace falta agregarle un parámetro a send().
  before_action { Notification::Contexto.origen = "web" }
end
