# Central de notificaciones — demo

Demo funcional de una central de notificaciones: el punto único por el que una aplicación
envía avisos a sus usuarios. Muestra la lógica, los flujos y las dos APIs del [diseño](https://docs.google.com/document/d/1gpoD-GDRY9ae6IR0nzSVZqHMuqY7Mdaq7WAnBNwKNbY/edit)
(definir una notificación y enviarla), con una interfaz para probarlo todo.

**Demo con datos ficticios. No sale ningún correo real.** El proveedor de correo es simulado:
lo que "envía" queda en su bandeja, visible en la consola.

Demo en línea: <https://central-notificaciones-demo.onrender.com>.
La página de inicio lleva a la propuesta, a la demo y al código; la consola está en `/consola`.
Para volver a los datos de ejemplo, usa "Reiniciar demo" al final de la consola.

## Qué demuestra

- **Definición única y validada.** Cada equipo declara su notificación una vez, como una
  clase que hereda de `Notification`: criticidad, datos, qué la hace única y su contenido.
  Una definición mal escrita impide arrancar la aplicación.
- **Punto único de envío.** Las acciones de negocio piden el envío con el `send()` de la
  notificación (`CertificadoEmitido.send`). Nadie más habla con el proveedor de correo.
- **Sin duplicados.** Una clave única por notificación y persona impide enviar dos veces lo
  mismo.
- **Nada se pierde.** `send()` guarda el pendiente en la misma transacción que la acción de
  negocio: si la acción falla, no queda notificación; si el proveedor se cae, el pendiente
  espera y sale cuando el proveedor vuelve.
- **Lo crítico primero.** El despachador saca los pendientes por criticidad y antigüedad.
- **Políticas por cliente.** Una empresa puede apagar lo que no es crítico. Lo crítico
  siempre tiene canal.
- **Frecuencia máxima.** Lo no crítico tiene un tope por persona; lo que excede se descarta y
  queda anotado.
- **Un contenido, varios canales.** El contenido se escribe una vez, con piezas (título,
  resumen, párrafo, destacado, lista, imagen y botón), y cada canal las dibuja a su manera.
  El simulador lo muestra por email, Slack, WhatsApp, SMS y push.
- **Historial completo.** Cada paso de cada notificación queda en una auditoría que solo se
  puede agregar: la propia base rechaza modificarla o borrarla.

## Las dos APIs

Son APIs de código, no endpoints HTTP.

```ruby
# 1.1 — Definir: una clase por notificación, en el módulo del equipo dueño
# (app/modulos/certificados/notificaciones/certificado_emitido.rb)
class CertificadoEmitido < Notification
  criticidad  :critica
  datos       :certificado_id, :curso, :imagen_curso, :link_certificado
  unica_por   :certificado_id

  contenido do
    titulo  "Tu certificado de {curso} está listo"
    resumen "Terminaste {curso}. Descarga tu certificado."
    imagen  "{imagen_curso}", alt: "Portada de {curso}"
    parrafo "Felicitaciones, terminaste {curso}."
    boton   "Descargar", link: "{link_certificado}"
  end
end

# 1.2 — Enviar: la acción de negocio pide el envío (app/modulos/certificados/emitir_certificado.rb)
CertificadoEmitido.send(
  empresa: 1,
  destinatarios: [3],        # usuarios, no correos: la central busca el contacto
  datos: { certificado_id: 789, curso: "Excel avanzado", imagen_curso: "https://...",
           link_certificado: "https://..." }
)
# → devuelve el id de la solicitud (UUID)
```

El nombre que queda en los pendientes y en la auditoría sale del nombre de la clase:
`CertificadoEmitido` se guarda como `certificado_emitido`.

Sobre el nombre `send`: el diseño lo llama así y se respetó; en producción se llamaría
`deliver`, la convención de Rails, para no pisar un método del lenguaje (en Ruby todo objeto
ya trae un `send`). Aquí `send` con un símbolo sigue siendo el de Ruby, y el trabajo lo hace `deliver`.

## Contenido por piezas

El contenido de una definición es una lista de piezas de un vocabulario cerrado: `titulo`,
`resumen`, `parrafo`, `destacado`, `lista`, `imagen` (URL y texto alternativo) y `boton`
(texto y link). Título y resumen son obligatorios; cualquier otra pieza se rechaza al
arrancar, y todo marcador `{dato}` tiene que ser un dato declarado, también en links, listas
e imágenes. La versión del contenido que se anota al enviar se calcula sobre las piezas.

Cada canal sabe dibujar cada pieza y define cómo degrada lo que no puede mostrar:

| Pieza | Email | Slack | WhatsApp | SMS | Push |
|---|---|---|---|---|---|
| Título | Asunto y encabezado | Encabezado | Primera línea en negrita | Se omite | Título |
| Resumen | Vista previa en la bandeja | Texto del aviso | Se omite | El mensaje | El texto |
| Párrafo y destacado | HTML con negrita | Texto con negrita | Texto con negrita | Se omite | Se omite |
| Lista | Viñetas | Viñetas | Líneas con guion | Se omite | Se omite |
| Imagen | Imagen | Imagen | Imagen adjunta | Se omite | Imagen al expandir |
| Botón | Botón | Botón | Botón de la plantilla | Link corto | Tocar la notificación abre el link |

Email es el único canal de la política: arma HTML, una versión en texto plano y la vista
previa. Slack, WhatsApp, SMS y push son canales simulados, fuera de la política; existen para
el simulador (`/simulador`), que muestra una misma definición por los cinco canales, qué
degradó cada uno y el mensaje crudo que recibiría cada proveedor. El simulador no pasa por
`send()` ni escribe nada en la base. En WhatsApp solo el certificado tiene plantilla
(simulada); sin plantilla, el botón pasa a link en el texto. El SMS lleva el resumen y un
link corto en 160 caracteres como máximo. La notificación push lleva el título y el resumen,
muestra la imagen al expandirla y, al tocarla, abre el link del botón.

El certificado lleva la portada del curso: un dato (`imagen_curso`) que la acción de emitir toma
del módulo de cursos. La solicitud de vacaciones lleva una ilustración fija.

## Recorrido de una solicitud

1. La acción de negocio abre una transacción, hace lo suyo y llama al `send()` de la
   notificación.
2. `send()` valida contra la definición y, por cada destinatario, guarda una clave única, un
   pendiente y la anotación `recibida`. Si la clave ya existía, anota `duplicada` y no crea
   pendiente. Devuelve el id de la solicitud.
3. El despachador, en segundo plano, toma los pendientes (lo crítico primero) y por cada uno:
   revisa que la persona sea de la empresa, aplica la política de la empresa para elegir el
   canal, busca el dato de contacto que pide ese canal, aplica el límite de frecuencia, anota
   `decision_enviar` y entrega por el canal. Lo que excede el límite queda `descartada`.
4. El canal email dibuja las piezas en un correo (HTML, texto plano y vista previa) y lo
   entrega al proveedor. Si el proveedor
   acepta, anota `enviada`, con la dirección a la que salió y la versión del contenido; si
   rechaza ese correo, `fallo_definitivo`; si no responde, `intento_fallido`, y el canal
   espera 5, 10 y 20 segundos antes de volver a probar. Si lo rechazado es crítico y la
   política tiene otro canal, se intenta por el siguiente.
5. El proveedor avisa después al receptor en qué terminó el envío: `entregada` o `rebotada`.

## Qué probar

| # | Escenario | Dónde | Qué se ve |
|---|---|---|---|
| 1 | Emitir un certificado | Consola → "Emitir certificado" | El recorrido completo y el correo armado en la bandeja |
| 2 | Emitirlo por la API | Consola → "Emitir certificado por la API" | El mismo recorrido, con origen api |
| 3 | La acción llama dos veces a send() | Casilla "la acción llama dos veces a send()" | Una sola notificación; la segunda queda como duplicada |
| 4 | La acción falla a la mitad | Casilla "la acción falla a la mitad" | Ni certificado ni notificación |
| 5 | Política del cliente | Empresa Minera Los Robles → "Saludar cumpleaños"; botón "Intentar apagar lo crítico" | "No enviada: política del cliente"; el rechazo |
| 6 | Límite de frecuencia | Cuatro avisos no críticos y un certificado a la misma persona | El cuarto queda descartado; el certificado pasa |
| 7 | Caída del proveedor | "Apagar el proveedor", emitir varias, "Encender el proveedor" | Esperan, se reintenta y salen con lo crítico primero |
| 8 | Historial | Pantalla Historial | Filtros y recorridos, con no enviadas y un rebote |
| 9 | Una definición, cinco canales | Pantalla Simulador | Cómo dibujan email, Slack, WhatsApp, SMS y push las mismas piezas, qué degrada cada uno y el mensaje crudo |

Personas de prueba en Andes Capacitación: una con un correo que rebota, una con un correo
inválido (el proveedor lo rechaza) y una sin correo (la central no tiene a dónde enviar).

## Cómo se corre

Requiere Ruby 4.0.9, la versión que fija `.ruby-version`. No necesita ningún servicio externo: la base es un archivo
SQLite dentro de la app.

```bash
bundle install
bin/rails db:prepare   # crea la base y siembra los datos de ejemplo
bin/rails server       # http://localhost:3000
bin/rails test         # las pruebas
```

No hay variables de entorno propias de la demo. En producción solo hace falta
`SECRET_KEY_BASE`, que Rails exige. La app corre en un solo proceso web: el despachador es un
hilo dentro de ese proceso.

Cada prueba lleva al inicio de su nombre el número del caso que cubre (por ejemplo,
`"13: recorrido feliz"`); esos números son los que cita la tabla de requisitos.

## Mapa del código

| Carpeta | Qué hay | Regla |
|---|---|---|
| `app/central/` | La central: `Notification` (la clase base y su `send`), el contenido por piezas, catálogo, despachador, políticas, canales (email, y Slack, WhatsApp, SMS y push simulados), proveedores, receptor, auditoría y configuración | Es la única que habla con un proveedor |
| `app/modulos/` | Los módulos de los equipos: sus notificaciones (una clase por archivo, en `notificaciones/`) y sus acciones de negocio | Solo heredan de `Notification` y llaman a `send()` |
| `app/controllers/` | Las entradas: pantallas y API | Llaman a las acciones; nunca a `send()` |
| `test/` | Las pruebas | `test/chequeos/` revisa el código mismo: que ninguna entrada llame a `send()` y que solo los canales hablen con un proveedor |

Los valores de la central (límite de frecuencia, esperas, tiempos) están en un solo lugar:
`app/central/notification/configuracion.rb`.

## Requisitos y dónde se ve cada uno

| Req. | Qué pide | Dónde se ve |
|---|---|---|
| R1 | Punto único de envío: nadie habla con el proveedor fuera de la central | Prueba automática 28, que revisa el código |
| R2 | Sin duplicados | Consola: emitir con la casilla "la acción llama dos veces a send()". Pruebas 6 a 10 |
| R3 | Frecuencia máxima para lo no crítico | Consola: cuatro avisos no críticos y uno crítico a la misma persona. Pruebas 19, 20, 32 y 33 |
| R4 | Criticidad declarada | Catálogo. Pruebas 1 y 2 |
| R5 | Política de envío configurable por cliente | Consola: un aviso opcional en Minera Los Robles. Prueba 17 |
| R6 | Lo crítico siempre tiene canal | Consola: botón "Intentar apagar lo crítico". Pruebas 18 y 42 |
| R7 | Canales extensibles sin tocar definiciones | Simulador: una definición dibujada por email, Slack, WhatsApp, SMS y push. Pruebas 29, 41, 56 y 67, con un canal de prueba y cuatro simulados |
| R8 | Definición única, validada: una clase por notificación | Catálogo: botón "Probar una definición inválida". Pruebas 1 a 3 y 38 |
| R9 | Se dispara desde la acción de negocio, igual por web, API o carga masiva | Consola: emitir por la pantalla y por la API. Pruebas 24 y 27. Hay dos entradas (web y API); la carga masiva no se construye |
| R10 | Historial completo e inmodificable | Los recorridos de la consola y del historial. Pruebas 12 y 13 |
| R11 | Auditoría a escala (12 millones al día, plazo de conservación, cada empresa ve lo suyo) | No se demuestra. Solo quedan el filtro obligatorio por empresa y los índices por empresa y fecha |
| R12 | Historial visible en una pantalla simple | Pantalla Historial. Prueba 30 |
| R13 | Volumen sin bloquear: send() solo guarda y responde; lo crítico primero | Consola: apagar el proveedor, emitir varias y encenderlo. Pruebas 4 y 23. El volumen de 500.000 por hora no se prueba |
| R14 | Nada se pierde si el proveedor falla | Consola: la casilla "la acción falla a la mitad" y el interruptor del proveedor. Pruebas 11 y 21 a 23 |

## Qué se simplificó

La demo muestra la lógica y los flujos. Esto es lo que cambia respecto del diseño completo.

| En el diseño | En la demo |
|---|---|
| Postgres | SQLite (un archivo dentro de la app) |
| SendGrid | Proveedor simulado; no sale ningún correo |
| Servidores de segundo plano en máquinas aparte | Un proceso en segundo plano dentro de la misma app |
| Varios servidores toman pendientes sin pisarse (FOR UPDATE SKIP LOCKED); si uno cae, otro sigue | Un solo despachador |
| Esperas de reintento que se duplican, de 1 a 15 minutos | Esperas de 5, 10 y 20 segundos, por canal: se prueba con el pendiente más crítico y, cuando pasa, salen todos por criticidad |
| Límite de frecuencia configurable; parte en 3 no críticas por persona y canal cada 24 h | El mismo valor, fijo en la configuración; cuenta la decisión de enviar |
| Respaldo de lo crítico por el canal siguiente | Hay un solo canal en la política (email); el respaldo se demuestra con canales de prueba (prueba 42) |
| Tope de destinatarios por llamada; lo que pase del tope lo reparte por lotes el equipo que envía | El tope existe (1.000); la central no ofrece el reparto por lotes |
| Auditoría a escala (R11) | No se demuestra |
| Tres entradas: web, API y carga masiva (R9) | Dos: web y API |
| Quién originó la solicitud (R10) | Se anota la notificación, que identifica al módulo dueño, y la entrada (web, api o interno) |
| Tiempos de salida: lo crítico en menos de 1 minuto, lo demás en menos de 15 (R13) | No se miden; solo se muestra el orden |
| Envío doble si una máquina cae justo después de que el proveedor acepta (limitación declarada en la propuesta) | Puede ocurrir; no se trata |
| Autenticación de la API | La API de ejemplo no pide credenciales |
| Aviso de SendGrid por la red, firmado | El proveedor simulado llama al receptor por código; sin firma |
| Auditoría separada por día, 90 días, archivo a S3 | Una tabla, sin archivo |
| La aplicación no tiene permiso para modificar ni borrar | La base rechaza UPDATE y DELETE sobre la auditoría con disparadores |
| Contador de frecuencia propio | Se cuenta sobre la auditoría |
| Cada empresa ve solo lo suyo (autenticación) | Sin login; la empresa se elige en un filtro obligatorio |
| Clave única por notificación, persona y unica_por | Texto legible, sin resumir |
| Agrupar lo excedente en un resumen (paso siguiente) | Solo descartar |
| Chequeos automáticos en la revisión de código | Dos pruebas automáticas que revisan el código |
| Pantalla de políticas fuera de alcance | Políticas sembradas; un botón solo para mostrar el rechazo |
| SQLite admite un solo escritor a la vez (propio de la demo) | No se muestran varias máquinas tomando pendientes |
| Slack, WhatsApp, SMS y push, cada uno con su proveedor | Canales simulados, fuera de la política: solo los usa el simulador y no envían nada |
| Plantillas de WhatsApp aprobadas por Meta; sin plantilla, sigue por el canal siguiente | Simuladas: solo el certificado tiene plantilla; sin ella, el simulador muestra el botón como link en el texto |
| Links cortos en el SMS | Simulados (https://nj.test/...); no llevan a ninguna parte |
| Imágenes con una dirección pública | La tarjeta de cumpleaños es una ruta de la demo: se ve dentro de la demo, no fuera |

## Riesgos declarados

- **Envío doble.** Si la app se cae justo después de que el proveedor acepta un correo y
  antes de guardarlo, ese correo puede salir dos veces. La demo no lo trata.
- **Un solo escritor.** SQLite admite un solo escritor a la vez, así que la demo no muestra
  varias máquinas tomando pendientes.
- **Sin login.** Cualquiera con el link puede usar la demo y la API de ejemplo.
