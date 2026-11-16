# Arranque de la central de notificaciones.

# Las definiciones de los equipos (app/modulos/*/definiciones.rb) son llamadas a
# Notification.define, no clases: se sacan de la carga automática de Rails y se cargan
# aquí, a mano, al arrancar.
definiciones = Rails.root.join("app/modulos/*/definiciones.rb")
Rails.autoloaders.main.ignore(definiciones)

Rails.application.config.to_prepare do
  # Se parte de un catálogo vacío y se registran todas. Si una definición está mal
  # escrita, Notification.define lanza un error aquí y la app no arranca (R8).
  Notification.catalogo.vaciar
  Dir[definiciones].sort.each { |archivo| load archivo }
end

# El despachador corre en segundo plano dentro del mismo proceso web: arranca con el
# servidor. No arranca en las pruebas (lo invocan a mano) ni en la consola o las tareas
# de Rails.
Rails.application.config.after_initialize do
  Notification::SegundoPlano.iniciar if defined?(Rails::Server) && !Rails.env.test?
end
