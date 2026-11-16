module Demo
  # "Reiniciar demo": vacía la base y la vuelve a sembrar, sin tener que redesplegar.
  module Reinicio
    TABLAS = %w[empresas usuarios certificados claves_unicas pendientes politicas_cliente
                estado_canales auditoria correos_simulados ajustes_demo].freeze

    def self.ejecutar
      base = ActiveRecord::Base.connection

      ActiveRecord::Base.transaction do
        # La auditoría no se deja borrar: sus disparadores lo impiden. Para reiniciar la
        # demo se quitan un momento y se vuelven a crear, idénticos, dentro de la misma
        # transacción. En un sistema real esto no existiría.
        disparadores = base.select_rows(
          "SELECT name, sql FROM sqlite_master WHERE type = 'trigger' AND tbl_name = 'auditoria'"
        )
        disparadores.each { |nombre, _sql| base.execute("DROP TRIGGER #{base.quote_table_name(nombre)}") }

        TABLAS.each { |tabla| base.execute("DELETE FROM #{base.quote_table_name(tabla)}") }
        base.execute("DELETE FROM sqlite_sequence") # los ids vuelven a partir de 1

        disparadores.each { |_nombre, sql| base.execute(sql) }

        Siembra.ejecutar
      end
    end
  end
end
