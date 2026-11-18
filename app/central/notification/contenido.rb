class Notification
  # Rellena el contenido neutro de una definición con los datos de un envío:
  # cada {marcador} se reemplaza por el valor de ese dato, como texto.
  module Contenido
    def self.rellenar(contenido, datos)
      datos = datos.to_h.transform_keys(&:to_sym)
      rellenar = ->(texto) { texto.gsub(ValidadorDefinicion::MARCADOR) { datos[$1.to_sym].to_s } }
      accion = contenido[:accion]

      {
        titulo: rellenar.call(contenido[:titulo]),
        cuerpo: rellenar.call(contenido[:cuerpo]),
        accion: accion && { texto: rellenar.call(accion[:texto]), link: rellenar.call(accion[:link]) }
      }
    end
  end
end
