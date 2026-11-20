# El diseño pasó a llamar "criticidad" a lo que antes era "importancia". Los valores no
# cambian (critica, informativa, opcional); solo el nombre de la columna.
class RenombrarImportanciaACriticidad < ActiveRecord::Migration[8.1]
  def up
    rename_column :pendientes, :importancia, :criticidad
    rename_column :politicas_cliente, :importancia, :criticidad
    renombrar_en_auditoria "importancia", "criticidad"
  end

  def down
    rename_column :pendientes, :criticidad, :importancia
    rename_column :politicas_cliente, :criticidad, :importancia
    renombrar_en_auditoria "criticidad", "importancia"
  end

  private

  # En SQLite, rename_column copia la tabla a una nueva, y en esa copia se pierden los
  # disparadores que impiden modificar o borrar la auditoría. Esta instrucción renombra
  # la columna en la misma tabla: los disparadores y las filas quedan como estaban.
  def renombrar_en_auditoria(antes, despues)
    execute "ALTER TABLE auditoria RENAME COLUMN #{antes} TO #{despues}"
  end
end
