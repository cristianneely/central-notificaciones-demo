CREATE TABLE "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE "empresas" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "nombre" varchar NOT NULL);
CREATE TABLE "usuarios" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "empresa_id" integer NOT NULL, "nombre" varchar NOT NULL, "email" varchar, "foto" varchar, "nacimiento" date);
CREATE INDEX "index_usuarios_on_empresa_id" ON "usuarios" ("empresa_id") /*application='CentralNotificaciones'*/;
CREATE TABLE "certificados" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "empresa_id" integer NOT NULL, "usuario_id" integer NOT NULL, "curso" varchar NOT NULL, "creado_en" datetime(6) NOT NULL);
CREATE TABLE "claves_unicas" ("clave" varchar NOT NULL, "expira_en" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_claves_unicas_on_clave" ON "claves_unicas" ("clave") /*application='CentralNotificaciones'*/;
CREATE TABLE "estado_canales" ("canal" varchar NOT NULL, "fallas_consecutivas" integer DEFAULT 0 NOT NULL, "proximo_intento_en" datetime(6));
CREATE UNIQUE INDEX "index_estado_canales_on_canal" ON "estado_canales" ("canal") /*application='CentralNotificaciones'*/;
CREATE TABLE "auditoria" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "solicitud_id" varchar NOT NULL, "empresa_id" integer NOT NULL, "usuario_id" integer NOT NULL, "notificacion" varchar NOT NULL, "criticidad" varchar NOT NULL, "evento" varchar NOT NULL, "canal" varchar, "motivo" varchar, "detalle" json NOT NULL, "creado_en" datetime(6) NOT NULL);
CREATE INDEX "index_auditoria_on_empresa_id_and_creado_en" ON "auditoria" ("empresa_id", "creado_en") /*application='CentralNotificaciones'*/;
CREATE INDEX "index_auditoria_on_solicitud_id" ON "auditoria" ("solicitud_id") /*application='CentralNotificaciones'*/;
CREATE INDEX "index_auditoria_on_usuario_id_and_creado_en" ON "auditoria" ("usuario_id", "creado_en") /*application='CentralNotificaciones'*/;
CREATE TRIGGER auditoria_no_se_modifica BEFORE UPDATE ON auditoria
BEGIN
  SELECT RAISE(ABORT, 'auditoria: solo se puede agregar');
END;
CREATE TRIGGER auditoria_no_se_borra BEFORE DELETE ON auditoria
BEGIN
  SELECT RAISE(ABORT, 'auditoria: solo se puede agregar');
END;
CREATE TABLE "ajustes_demo" ("clave" varchar NOT NULL, "valor" varchar NOT NULL);
CREATE UNIQUE INDEX "index_ajustes_demo_on_clave" ON "ajustes_demo" ("clave") /*application='CentralNotificaciones'*/;
CREATE TABLE "pendientes" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "solicitud_id" varchar NOT NULL, "notificacion" varchar NOT NULL, "empresa_id" integer NOT NULL, "usuario_id" integer NOT NULL, "datos" json NOT NULL, "criticidad" varchar NOT NULL, "prioridad" integer NOT NULL, "creado_en" datetime(6) NOT NULL);
CREATE TABLE "politicas_cliente" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "empresa_id" integer NOT NULL, "criticidad" varchar NOT NULL, "canal" varchar NOT NULL, "habilitado" boolean NOT NULL);
CREATE UNIQUE INDEX "index_politicas_cliente_on_empresa_id_and_criticidad_and_canal" ON "politicas_cliente" ("empresa_id", "criticidad", "canal") /*application='CentralNotificaciones'*/;
CREATE TABLE "correos_simulados" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "id_proveedor" varchar, "solicitud_id" varchar NOT NULL, "usuario_id" integer NOT NULL, "para" varchar NOT NULL, "asunto" varchar NOT NULL, "cuerpo" text NOT NULL, "aceptado_en" datetime(6) NOT NULL, "aviso_enviado" boolean DEFAULT FALSE NOT NULL, "vista_previa" varchar, "html" text);
INSERT INTO "schema_migrations" (version) VALUES
('20261120000001'),
('20261119000001'),
('20261118000001'),
('20261115000001');

