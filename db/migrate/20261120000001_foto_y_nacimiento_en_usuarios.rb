# Cada persona suma su foto (la ruta de la imagen) y su fecha de nacimiento: el aviso de
# cumpleaños busca aquí a quienes cumplen hoy y muestra su foto. Ambas pueden venir vacías.
class FotoYNacimientoEnUsuarios < ActiveRecord::Migration[8.1]
  def change
    add_column :usuarios, :foto, :string
    add_column :usuarios, :nacimiento, :date
  end
end
