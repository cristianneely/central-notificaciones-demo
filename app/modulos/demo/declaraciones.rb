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
       "Empresa Minera Los Robles → \"Avisar los cumpleaños de hoy\"; botón \"Intentar apagar lo crítico\"",
       "\"No enviada: política del cliente\" para toda la empresa; el rechazo"],
      [6, "Límite de frecuencia", "Cuatro avisos no críticos y un certificado a la misma persona",
       "El cuarto queda descartado; el certificado pasa"],
      [7, "Caída del proveedor", "\"Apagar el proveedor\", emitir varias, \"Encender el proveedor\"",
       "Esperan, se reintenta y salen con lo crítico primero"],
      [8, "Historial", "Pantalla Historial", "Filtros y recorridos, con no enviadas y un rebote"],
      [9, "Una definición, cinco canales", "Pantalla Simulador",
       "Cómo dibujan email, Slack, WhatsApp, SMS y push las mismas piezas, qué degrada cada uno y el mensaje crudo"],
      [10, "Cumpleaños a toda la empresa", "Empresa Andes Capacitación → \"Avisar los cumpleaños de hoy\"",
       "Un aviso a las ocho personas, con el nombre y la foto de quienes cumplen hoy; la segunda vez, duplicado"]
    ].freeze

    # [En el documento, En la demo]
    SIMPLIFICACIONES = [
      ["Postgres", "SQLite (un archivo dentro de la app)"],
      ["SendGrid", "Proveedor simulado; no sale ningún correo"],
      ["Servidores de segundo plano en máquinas aparte", "Un proceso en segundo plano dentro de la misma app"],
      ["Varios servidores toman pendientes sin pisarse (FOR UPDATE SKIP LOCKED); si uno cae, otro sigue", "Un solo despachador"],
      ["Esperas de reintento que se duplican, de 1 a 15 minutos",
       "Esperas de 5, 10 y 20 segundos, por canal: se prueba con el pendiente más crítico y, cuando pasa, " \
       "salen todos por criticidad"],
      ["Límite de frecuencia configurable; parte en 3 no críticas por persona y canal cada 24 h",
       "El mismo valor, fijo en la configuración; cuenta la decisión de enviar"],
      ["Respaldo de lo crítico por el canal siguiente",
       "Hay un solo canal en la política (email); el respaldo se demuestra con canales de prueba (prueba 42)"],
      ["Tope de destinatarios por llamada; lo que pase del tope lo reparte por lotes el equipo que envía",
       "El tope existe (1.000); la central no ofrece el reparto por lotes"],
      ["Auditoría a escala (R11)", "No se demuestra"],
      ["Tres entradas: web, API y carga masiva (R9)", "Dos: web y API"],
      ["Quién originó la solicitud (R10)",
       "Se anota la notificación, que identifica al módulo dueño, y la entrada (web, api o interno)"],
      ["Tiempos de salida: lo crítico en menos de 1 minuto, lo demás en menos de 15 (R13)",
       "No se miden; solo se muestra el orden"],
      ["Envío doble si una máquina cae justo después de que el proveedor acepta " \
       "(limitación declarada en la propuesta)",
       "Puede ocurrir; no se trata"],
      ["Autenticación de la API", "La API de ejemplo no pide credenciales"],
      ["Aviso de SendGrid por la red, firmado", "El proveedor simulado llama al receptor por código; sin firma"],
      ["Auditoría separada por día, 90 días, archivo a S3", "Una tabla, sin archivo"],
      ["La aplicación no tiene permiso para modificar ni borrar",
       "La base rechaza UPDATE y DELETE sobre la auditoría con disparadores"],
      ["Contador de frecuencia propio", "Se cuenta sobre la auditoría"],
      ["Cada empresa ve solo lo suyo (autenticación)", "Sin login; la empresa se elige en un filtro obligatorio"],
      ["Clave única por notificación, persona y unica_por", "Texto legible, sin resumir"],
      ["Agrupar lo excedente en un resumen (paso siguiente)", "Solo descartar"],
      ["Chequeos automáticos en la revisión de código", "Dos pruebas automáticas que revisan el código"],
      ["Pantalla de políticas fuera de alcance", "Políticas sembradas; un botón solo para mostrar el rechazo"],
      ["SQLite admite un solo escritor a la vez (propio de la demo)",
       "No se muestran varias máquinas tomando pendientes"],
      ["Slack, WhatsApp, SMS y push, cada uno con su proveedor",
       "Canales simulados, fuera de la política: solo los usa el simulador y no envían nada"],
      ["Plantillas de WhatsApp aprobadas por Meta; sin plantilla, sigue por el canal siguiente",
       "Simuladas: solo el certificado tiene plantilla; sin ella, el simulador muestra el botón como link en el texto"],
      ["Links cortos en el SMS", "Simulados (https://nj.test/...); no llevan a ninguna parte"],
      ["Imágenes con una dirección pública",
       "Las portadas, la ilustración y los avatares son rutas de la demo: se ven dentro de la demo, no fuera"],
      ["Fotos de las personas", "Avatares dibujados con las iniciales; quien no tiene foto lleva una de respaldo"],
      ["Fechas de nacimiento de las personas",
       "Relativas al día en que se siembra la demo: si pasa un día sin reiniciarla, nadie cumple hoy. " \
       "Quien nació un 29 de febrero no aparece los años que no son bisiestos"],
      ["Avisar a una empresa de cualquier tamaño",
       "Más de 1.000 personas superaría el tope de send(); el módulo tendría que partir el envío en tandas. " \
       "Las empresas de la demo tienen ocho"]
    ].freeze

    # [Requisito, Qué pide, Dónde se ve en la demo]
    REQUISITOS = [
      ["R1", "Punto único de envío: nadie habla con el proveedor fuera de la central",
       "Prueba automática 28, que revisa el código"],
      ["R2", "Sin duplicados",
       "Consola: emitir con la casilla \"la acción llama dos veces a send()\". Pruebas 6 a 10"],
      ["R3", "Frecuencia máxima para lo no crítico",
       "Consola: cuatro avisos no críticos y uno crítico a la misma persona. Pruebas 19, 20, 32 y 33"],
      ["R4", "Criticidad declarada", "Catálogo. Pruebas 1 y 2"],
      ["R5", "Política de envío configurable por cliente",
       "Consola: un aviso opcional en Minera Los Robles. Prueba 17"],
      ["R6", "Lo crítico siempre tiene canal", "Consola: botón \"Intentar apagar lo crítico\". Pruebas 18 y 42"],
      ["R7", "Canales extensibles sin tocar definiciones",
       "Simulador: una definición dibujada por email, Slack, WhatsApp, SMS y push. Pruebas 29, 41, 56 y 67, " \
       "con un canal de prueba y cuatro simulados"],
      ["R8", "Definición única, validada: una clase por notificación",
       "Catálogo: botón \"Probar una definición inválida\". Pruebas 1 a 3 y 38"],
      ["R9", "Se dispara desde la acción de negocio, igual por web, API o carga masiva",
       "Consola: emitir por la pantalla y por la API. Pruebas 24 y 27. Hay dos entradas (web y API); " \
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
