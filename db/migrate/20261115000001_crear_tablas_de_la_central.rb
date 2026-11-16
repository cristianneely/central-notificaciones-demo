# Todas las tablas de la demo, en una sola migración.
#
# No hay llaves foráneas a propósito: un pendiente puede nombrar a un usuario que no
# existe (el despachador lo anota como "sin contacto"), y la auditoría guarda lo que
# pasó aunque después cambien los datos de origen.
class CrearTablasDeLaCentral < ActiveRecord::Migration[8.1]
  def change
    # --- Usuarios: empresas y personas (datos sembrados) ---------------------------
    create_table :empresas do |t|
      t.string :nombre, null: false
    end

    create_table :usuarios do |t|
      t.integer :empresa_id, null: false
      t.string :nombre, null: false
      t.string :email # texto libre: puede venir vacío o mal escrito
    end
    add_index :usuarios, :empresa_id

    # --- La acción de negocio de ejemplo -------------------------------------------
    create_table :certificados do |t|
      t.integer :empresa_id, null: false
      t.integer :usuario_id, null: false
      t.string :curso, null: false
      t.datetime :creado_en, null: false
    end

    # --- La central ----------------------------------------------------------------
    # Claves únicas (R2): el índice único es el que impide el duplicado.
    create_table :claves_unicas, id: false do |t|
      t.string :clave, null: false
      t.datetime :expira_en, null: false
    end
    add_index :claves_unicas, :clave, unique: true

    # Pendientes: la fila de salida. Se guardan en la misma base y en la misma
    # transacción que la acción de negocio (D1).
    create_table :pendientes do |t|
      t.string :solicitud_id, null: false
      t.string :notificacion, null: false
      t.integer :empresa_id, null: false
      t.integer :usuario_id, null: false
      t.json :datos, null: false
      t.string :importancia, null: false
      t.integer :prioridad, null: false # 0 crítica, 1 informativa, 2 opcional
      t.datetime :creado_en, null: false
    end

    # Políticas por cliente (R5): lo que una empresa apagó.
    create_table :politicas_cliente do |t|
      t.integer :empresa_id, null: false
      t.string :importancia, null: false
      t.string :canal, null: false
      t.boolean :habilitado, null: false
    end
    add_index :politicas_cliente, [:empresa_id, :importancia, :canal], unique: true

    # Estado de cada canal para los reintentos (R14).
    create_table :estado_canales, id: false do |t|
      t.string :canal, null: false
      t.integer :fallas_consecutivas, null: false, default: 0
      t.datetime :proximo_intento_en
    end
    add_index :estado_canales, :canal, unique: true

    # Auditoría (R10): solo se puede agregar.
    create_table :auditoria do |t|
      t.string :solicitud_id, null: false
      t.integer :empresa_id, null: false
      t.integer :usuario_id, null: false
      t.string :notificacion, null: false
      t.string :importancia, null: false
      t.string :evento, null: false
      t.string :canal
      t.string :motivo
      t.json :detalle, null: false
      t.datetime :creado_en, null: false
    end
    add_index :auditoria, [:empresa_id, :creado_en]
    add_index :auditoria, :solicitud_id
    add_index :auditoria, [:usuario_id, :creado_en]

    # Disparadores: la propia base rechaza modificar o borrar filas de la auditoría.
    reversible do |direccion|
      direccion.up do
        execute <<~SQL
          CREATE TRIGGER auditoria_no_se_modifica BEFORE UPDATE ON auditoria
          BEGIN
            SELECT RAISE(ABORT, 'auditoria: solo se puede agregar');
          END;
        SQL
        execute <<~SQL
          CREATE TRIGGER auditoria_no_se_borra BEFORE DELETE ON auditoria
          BEGIN
            SELECT RAISE(ABORT, 'auditoria: solo se puede agregar');
          END;
        SQL
      end
      direccion.down do
        execute "DROP TRIGGER auditoria_no_se_modifica"
        execute "DROP TRIGGER auditoria_no_se_borra"
      end
    end

    # --- El proveedor simulado (no es parte de la central) ---------------------------
    # Guarda el correo completo porque representa lo que tendría el proveedor real.
    create_table :correos_simulados do |t|
      t.string :id_proveedor
      t.string :solicitud_id, null: false
      t.integer :usuario_id, null: false
      t.string :para, null: false
      t.string :asunto, null: false
      t.text :cuerpo, null: false
      t.string :accion_texto
      t.string :accion_link
      t.datetime :aceptado_en, null: false
      t.boolean :aviso_enviado, null: false, default: false
    end

    create_table :ajustes_demo, id: false do |t|
      t.string :clave, null: false
      t.string :valor, null: false
    end
    add_index :ajustes_demo, :clave, unique: true
  end
end
