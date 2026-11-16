# La central de notificaciones. Los módulos de los equipos solo conocen dos operaciones:
#
#   Notification.define  (API 1.1) — declara una notificación en el catálogo.
#   Notification.send    (API 1.2) — pide enviarla.
#
# Todo lo demás (despachador, políticas, canales, proveedor, receptor, auditoría) vive en
# app/central/notification/ y es interno de la central.
module Notification
  # Una definición que no cumple las reglas de 1.1. Trae todos los problemas juntos.
  class DefinicionInvalida < StandardError
    attr_reader :errores

    def initialize(nombre, errores)
      @errores = errores
      super("#{nombre}: #{errores.join('; ')}")
    end
  end

  # API 1.1 — Declara una notificación. La valida y la deja en el catálogo (R8).
  # Si la definición está mal escrita lanza DefinicionInvalida: la app no arranca.
  def self.define(nombre, **opciones)
    catalogo.registrar(nombre, **opciones)
  end

  # El catálogo de la aplicación: todas las definiciones registradas.
  def self.catalogo
    @catalogo ||= Catalogo.new
  end
end
