# El correo ahora se arma por piezas: la bandeja del proveedor simulado guarda el HTML,
# la vista previa y la versión en texto plano (en `cuerpo`). El botón va dentro del HTML,
# así que sus dos columnas sobran.
class CorreoSimuladoConHtml < ActiveRecord::Migration[8.1]
  def change
    add_column :correos_simulados, :vista_previa, :string
    add_column :correos_simulados, :html, :text
    remove_column :correos_simulados, :accion_texto, :string
    remove_column :correos_simulados, :accion_link, :string
  end
end
