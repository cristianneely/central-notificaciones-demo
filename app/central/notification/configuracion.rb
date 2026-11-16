module Notification
  # Los valores de la central, en un solo lugar. Cambiar un número aquí cambia el
  # comportamiento de toda la central; ninguna otra parte del código los repite.
  module Configuracion
    # Importancias que una definición puede declarar (R4) y su prioridad en la fila de
    # pendientes: mientras menor el número, antes sale ("lo crítico primero", R13).
    PRIORIDADES = { critica: 0, informativa: 1, opcional: 2 }.freeze
  end
end
