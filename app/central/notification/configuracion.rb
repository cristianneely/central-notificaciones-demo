class Notification
  # Los valores de la central, en un solo lugar. Cambiar un número aquí cambia el
  # comportamiento de toda la central; ninguna otra parte del código los repite.
  module Configuracion
    # Criticidades que una definición puede declarar (R4) y su prioridad en la fila de
    # pendientes: mientras menor el número, antes sale ("lo crítico primero", R13).
    PRIORIDADES = { critica: 0, informativa: 1, opcional: 2 }.freeze

    # Tope de destinatarios por llamada a send(), para no alargar la operación de negocio
    # de quien llama. Un envío más grande lo reparte por lotes el equipo que envía.
    TOPE_DESTINATARIOS = 1_000

    # Bloqueo de duplicados (R2): cuánto tiempo una clave única impide repetir el envío.
    BLOQUEO_DUPLICADOS = 24.hours

    # Límite de frecuencia (R3): cuántas notificaciones no críticas puede recibir una
    # persona por un canal dentro de la ventana. Lo crítico está exento.
    LIMITE_FRECUENCIA = 3
    VENTANA_LIMITE = 24.hours

    # Política por defecto: por qué canales sale cada criticidad (R5). Lo que una empresa
    # apaga se guarda aparte, en la tabla politicas_cliente.
    POLITICA_POR_DEFECTO = {
      "critica" => ["email"],
      "informativa" => ["email"],
      "opcional" => ["email"]
    }.freeze

    # Cada cuántos segundos el despachador revisa los pendientes, y cuántos toma por vuelta.
    INTERVALO_DESPACHADOR = 1
    PENDIENTES_POR_VUELTA = 20

    # Reintentos por canal (R14): segundos de espera tras la 1.ª, la 2.ª y la 3.ª falla
    # seguida del proveedor. De la tercera en adelante se repite la última.
    ESPERAS_CANAL = [5, 10, 20].freeze

    # Cuánto demora el proveedor simulado en avisar el estado final de un correo.
    DEMORA_AVISO_PROVEEDOR = 2.seconds
  end
end
