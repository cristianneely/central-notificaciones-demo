class Notification
  # El estado de un canal para los reintentos (R14): cuántas veces seguidas falló su
  # proveedor y cuándo se vuelve a probar.
  class EstadoCanal < ApplicationRecord
    self.table_name = "estado_canales"
    self.primary_key = "canal"

    # El estado de ese canal. Si nunca falló todavía no tiene fila: parte en cero.
    def self.para(canal)
      find_or_initialize_by(canal: canal)
    end

    # ¿Hay algún canal esperando su próximo intento?
    def self.alguno_en_espera?(ahora)
      where("proximo_intento_en > ?", ahora).exists?
    end

    # El proveedor del canal no respondió: suma una falla y fija cuándo se vuelve a
    # probar. La espera crece con cada falla seguida: 5, 10 y 20 segundos.
    def self.registrar_falla(canal, ahora)
      estado = para(canal)
      estado.fallas_consecutivas += 1
      esperas = Configuracion::ESPERAS_CANAL
      espera = esperas[estado.fallas_consecutivas - 1] || esperas.last
      estado.proximo_intento_en = ahora + espera
      estado.save!
      estado
    end

    # El proveedor respondió (aceptó o rechazó): el canal vuelve a estar sano.
    def self.reiniciar(canal)
      where(canal: canal).delete_all
    end

    def en_espera?(ahora)
      proximo_intento_en.present? && proximo_intento_en > ahora
    end

    # Segundos que faltan para el próximo intento (0 si no está en espera).
    def segundos_para_reintentar(ahora)
      en_espera?(ahora) ? (proximo_intento_en - ahora).ceil : 0
    end
  end
end
