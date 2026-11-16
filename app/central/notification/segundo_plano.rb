module Notification
  # El trabajo en segundo plano de la demo: un hilo dentro del mismo proceso web que,
  # cada segundo, da una vuelta del despachador y hace llegar los avisos del proveedor
  # simulado. En el documento son servidores aparte; aquí es un solo hilo.
  module SegundoPlano
    # Un paso. Las pruebas lo llaman a mano. Nunca lanza un error: lo anota en el log y
    # sigue, para que una falla puntual no deje a la demo sin despachador.
    def self.tic
      Despachador.vuelta
      Proveedores::Simulado.enviar_avisos
    rescue StandardError => error
      Rails.logger.error("[central] error en segundo plano: #{error.class}: #{error.message}")
    end

    # Arranca el hilo. Se llama una sola vez, cuando parte el servidor web.
    def self.iniciar
      Thread.new do
        loop do
          # executor.wrap le da al hilo una conexión a la base y la devuelve al terminar.
          Rails.application.executor.wrap { tic }
          sleep Configuracion::INTERVALO_DESPACHADOR
        end
      end
    end
  end
end
