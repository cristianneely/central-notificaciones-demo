Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Página de inicio: qué es la demo, dónde está la propuesta y el código, qué mirar.
  root "inicio#index"

  # Consola de demo: aquí se disparan las acciones y se ve qué hace la central.
  get "consola" => "consola#index"
  get "consola/listas" => "consola#listas"                  # las listas solas, para refrescarlas
  post "consola/proveedor" => "consola#proveedor"           # interruptor del proveedor simulado
  post "consola/apagar_critico" => "consola#apagar_critico" # muestra el rechazo de R6
  post "consola/reiniciar" => "consola#reiniciar"           # vuelve a los datos semilla

  # Las otras pantallas.
  get "catalogo" => "catalogo#index"
  post "catalogo/definicion_invalida" => "catalogo#definicion_invalida"
  post "catalogo/probar_send" => "catalogo#probar_send"
  # Si alguien recarga la página después de usar uno de esos botones, vuelve al catálogo.
  get "catalogo/definicion_invalida", to: redirect("/catalogo")
  get "catalogo/probar_send", to: redirect("/catalogo")
  get "historial" => "historial#index"
  get "acerca" => "acerca#index"

  # Acciones de negocio desde la pantalla (puerta web).
  post "acciones/emitir_certificado" => "acciones#emitir_certificado"
  post "acciones/recordatorio" => "acciones#recordatorio"
  post "acciones/encuesta" => "acciones#encuesta"
  post "acciones/cumpleanos" => "acciones#cumpleanos"

  # La misma acción "emitir certificado", por la API (puerta API).
  post "api/certificados" => "api/certificados#create"

  # Receptor: por aquí el proveedor de correo avisa el estado final de un envío.
  post "receptor/proveedor" => "receptor#proveedor"
end
