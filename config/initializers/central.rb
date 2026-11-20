# Arranque de la central de notificaciones.

# Cada notificación es una clase en app/modulos/<módulo>/notificaciones/ (esas carpetas
# se declaran en config/application.rb). Aquí se validan todas al arrancar.
Rails.application.config.to_prepare do
  # Se parte de un catálogo vacío y se registra la clase de cada archivo, en orden. Si
  # una definición está mal escrita, el catálogo lanza un error aquí, con todos sus
  # problemas juntos, y la app no arranca (R8).
  Notification.catalogo.vaciar
  Dir[Rails.root.join("app/modulos/*/notificaciones/*.rb")].sort.each do |archivo|
    Notification.catalogo.registrar(File.basename(archivo, ".rb").camelize.constantize)
  end
end

# El despachador corre en segundo plano dentro del mismo proceso web: arranca con el
# servidor. No arranca en las pruebas (lo invocan a mano) ni en la consola o las tareas
# de Rails.
Rails.application.config.after_initialize do
  Notification::SegundoPlano.iniciar if defined?(Rails::Server) && !Rails.env.test?
end
