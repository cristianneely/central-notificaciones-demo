module Demo
  # Lo que la demo declara: en qué se simplificó el diseño del documento y dónde se ve
  # cada requisito. Lo muestra la página "Acerca".
  module Declaraciones
    # El documento que la demo implementa y el código. Los usan el menú, el inicio y Acerca.
    PROPUESTA_URL = "https://docs.google.com/document/d/1gpoD-GDRY9ae6IR0nzSVZqHMuqY7Mdaq7WAnBNwKNbY/edit".freeze
    CODIGO_URL = "https://github.com/cristianneely/central-notificaciones-demo".freeze

    # [Número, Escenario, Dónde, Qué se ve]. De aquí salen "Qué probar" de la consola y del README.
    ESCENARIOS = [
      [1, "Emitir un certificado", "Consola → \"Emitir certificado\"",
       "El recorrido completo y el correo armado en la bandeja"],
      [2, "Emitirlo por la API", "Consola → \"Emitir certificado por la API\"",
       "El mismo recorrido, con origen api"],
      [3, "La acción llama dos veces a send()", "Casilla \"la acción llama dos veces a send()\"",
       "Una sola notificación; la segunda queda como duplicada"],
      [4, "La acción falla a la mitad", "Casilla \"la acción falla a la mitad\"",
       "Ni certificado ni notificación"],
      [5, "Política del cliente",
       "Empresa Minera Los Robles → \"Saludar cumpleaños\"; botón \"Intentar apagar lo crítico\"",
       "\"No enviada: política del cliente\"; el rechazo"],
      [6, "Límite de frecuencia", "Cuatro avisos no críticos y un certificado a la misma persona",
       "El cuarto queda retenido; el certificado pasa"],
      [7, "Caída del proveedor", "\"Apagar el proveedor\", emitir varias, \"Encender el proveedor\"",
       "Esperan, se reintenta y salen con lo crítico primero"],
      [8, "Historial", "Pantalla Historial", "Filtros y recorridos, con no enviadas y un rebote"]
    ].freeze

    # [En el documento, En la demo]
    SIMPLIFICACIONES = [
      ["Postgres", "SQLite (un archivo dentro de la app)"],
      ["SendGrid", "Proveedor simulado; no sale ningún correo"],
      ["Servidores de segundo plano en máquinas aparte", "Un proceso en segundo plano dentro de la misma app"],
      ["Varias máquinas toman pendientes; si una cae, otra sigue", "Un solo despachador"],
      ["Reintentos con esperas de minutos", "Esperas de 5, 10 y 20 segundos"],
      ["Reintentos \"con esperas cada vez más largas\" (no dice si por correo o por proveedor)",
       "Por canal: se prueba con el pendiente más crítico y, cuando pasa, salen todos por importancia"],
      ["N y período del límite de frecuencia, pendientes",
       "3 no críticas por persona y canal en 24 h; cuenta la decisión de enviar"],
      ["Varios canales y respaldo para lo crítico (cuando exista un segundo canal)", "Un solo canal por envío"],
      ["Auditoría a escala (R11)", "No se demuestra"],
      ["Tres puertas de entrada: web, API y carga masiva (R9)", "Dos: web y API"],
      ["Quién originó la solicitud (R10)",
       "Se anota la notificación, que identifica al módulo dueño, y la puerta (web, api o interno)"],
      ["Tiempos de salida: lo crítico en menos de 1 minuto, lo demás en menos de 15 (R13)",
       "No se miden; solo se muestra el orden"],
      ["Envío doble si la app cae justo después de que el proveedor acepta (fuera del documento)",
       "Puede ocurrir; no se trata"],
      ["Autenticación de la API", "La API de ejemplo no pide credenciales"],
      ["Aviso de SendGrid por la red, firmado", "El proveedor simulado llama al receptor por código; sin firma"],
      ["Auditoría separada por día, 90 días, archivo a S3", "Una tabla, sin archivo"],
      ["La aplicación no tiene permiso para modificar ni borrar",
       "La base rechaza UPDATE y DELETE sobre la auditoría con disparadores"],
      ["Contador de frecuencia propio", "Se cuenta sobre la auditoría"],
      ["Cada empresa ve solo lo suyo (autenticación)", "Sin login; la empresa se elige en un filtro obligatorio"],
      ["Clave única (el documento no fija formato)", "Texto legible, sin resumir"],
      ["Resumen para lo excedente (opcional)", "Solo retener"],
      ["Chequeos automáticos en la revisión de código", "Dos pruebas automáticas que revisan el código"],
      ["Pantalla de políticas fuera de alcance", "Políticas sembradas; un botón solo para mostrar el rechazo"],
      ["SQLite admite un solo escritor a la vez (propio de la demo)",
       "No se muestran varias máquinas tomando pendientes"]
    ].freeze

    # [Requisito, Qué pide, Dónde se ve en la demo]
    REQUISITOS = [
      ["R1", "Punto único de envío: nadie habla con el proveedor fuera de la central",
       "Prueba automática 28, que revisa el código"],
      ["R2", "Sin duplicados",
       "Consola: emitir con la casilla \"la acción llama dos veces a send()\". Pruebas 6 a 10"],
      ["R3", "Frecuencia máxima para lo no crítico",
       "Consola: cuatro avisos no críticos y uno crítico a la misma persona. Pruebas 19, 20, 32 y 33"],
      ["R4", "Importancia declarada", "Catálogo. Pruebas 1 y 2"],
      ["R5", "Política de envío configurable por cliente",
       "Consola: un aviso opcional en Minera Los Robles. Prueba 17"],
      ["R6", "Lo crítico siempre tiene canal", "Consola: botón \"Intentar apagar lo crítico\". Prueba 18"],
      ["R7", "Canales extensibles sin tocar definiciones", "Prueba 29, con un canal de prueba"],
      ["R8", "Definición única, validada",
       "Catálogo: botón \"Probar una definición inválida\". Pruebas 1 a 3"],
      ["R9", "Se dispara desde la acción de negocio, igual por web, API o carga masiva",
       "Consola: emitir por la pantalla y por la API. Pruebas 24 y 27. Hay dos puertas (web y API); " \
       "la carga masiva no se construye"],
      ["R10", "Historial completo e inmodificable",
       "Los recorridos de la consola y del historial. Pruebas 12 y 13"],
      ["R11", "Auditoría a escala (12 millones al día, plazo de conservación, cada empresa ve lo suyo)",
       "No se demuestra. Solo quedan el filtro obligatorio por empresa y los índices por empresa y fecha"],
      ["R12", "Historial visible en una pantalla simple", "Pantalla Historial. Prueba 30"],
      ["R13", "Volumen sin bloquear: send() solo guarda y responde; lo crítico primero",
       "Consola: apagar el proveedor, emitir varias y encenderlo. Pruebas 4 y 23. " \
       "El volumen de 500.000 por hora no se prueba"],
      ["R14", "Nada se pierde si el proveedor falla",
       "Consola: la casilla \"la acción falla a la mitad\" y el interruptor del proveedor. Pruebas 11 y 21 a 23"]
    ].freeze
  end
end
