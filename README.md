# Central de notificaciones — demo

Demo funcional de una central de notificaciones: el punto único por el que una aplicación
envía avisos a sus usuarios. Muestra la lógica, los flujos y las dos APIs del diseño
(definir una notificación y enviarla), con una interfaz para probarlo todo.

**Demo con datos ficticios. No sale ningún correo real.** El proveedor de correo es simulado:
lo que "envía" queda en su bandeja, visible en la consola.

Demo en línea: <https://central-notificaciones-demo.onrender.com>. Está en un plan gratuito:
si nadie la usó en los últimos minutos puede tardar cerca de un minuto en despertar, y al
despertar la base vuelve a los datos de ejemplo.

## Qué demuestra

- **Definición única y validada.** Cada equipo declara su notificación una vez, con
  `Notification.define`: importancia, datos, qué la hace única y su contenido. Una definición
  mal escrita impide arrancar la aplicación.
- **Punto único de envío.** Las acciones de negocio piden el envío con `Notification.send`.
  Nadie más habla con el proveedor de correo.
- **Sin duplicados.** Una clave única por notificación y persona impide enviar dos veces lo
  mismo.
- **Nada se pierde.** `send()` guarda el pendiente en la misma transacción que la acción de
  negocio: si la acción falla, no queda notificación; si el proveedor se cae, el pendiente
  espera y sale cuando el proveedor vuelve.
- **Lo crítico primero.** El despachador saca los pendientes por importancia y antigüedad.
- **Políticas por cliente.** Una empresa puede apagar lo que no es crítico. Lo crítico
  siempre tiene canal.
- **Frecuencia máxima.** Lo no crítico tiene un tope por persona; lo que excede se retiene y
  queda anotado.
- **Historial completo.** Cada paso de cada notificación queda en una auditoría que solo se
  puede agregar: la propia base rechaza modificarla o borrarla.

## Las dos APIs

Son APIs de código, no endpoints HTTP.

```ruby
# 1.1 — Definir: un equipo declara su notificación (app/modulos/certificados/definiciones.rb)
Notification.define "certificado_emitido",
  importancia: :critica,
  datos: [:certificado_id, :curso, :link_certificado],
  unica_por: [:certificado_id],
  contenido: {
    titulo: "Tu certificado de {curso} está listo",
    cuerpo: "Felicitaciones, terminaste {curso}.",
    accion: { texto: "Descargar", link: "{link_certificado}" }
  }

# 1.2 — Enviar: la acción de negocio pide el envío (app/modulos/certificados/emitir_certificado.rb)
Notification.send "certificado_emitido",
  empresa: 1,
  destinatarios: [3],        # usuarios, no correos: la central busca el contacto
  datos: { certificado_id: 789, curso: "Excel avanzado", link_certificado: "https://..." }
# → devuelve el id de la solicitud (UUID)
```

Sobre el nombre `send`: el enunciado lo llama así y se respetó; en producción se llamaría
`deliver`, la convención de Rails, para no pisar un método del lenguaje (en Ruby todo objeto
ya trae un `send`). Aquí es seguro porque `Notification` es un módulo propio y no un modelo de
base de datos.

## Recorrido de una solicitud

1. La acción de negocio abre una transacción, hace lo suyo y llama a `Notification.send`.
2. `send()` valida contra la definición y, por cada destinatario, guarda una clave única, un
   pendiente y la anotación `recibida`. Si la clave ya existía, anota `duplicada` y no crea
   pendiente. Devuelve el id de la solicitud.
3. El despachador, en segundo plano, toma los pendientes (lo crítico primero) y por cada uno:
   busca el contacto, aplica la política de la empresa, aplica el límite de frecuencia, anota
   `decision_enviar` y entrega por el canal.
4. El canal email adapta el contenido a un correo y lo entrega al proveedor. Si el proveedor
   acepta, anota `enviada`; si rechaza ese correo, `fallo_definitivo`; si no responde,
   `intento_fallido`, y el canal espera 5, 10 y 20 segundos antes de volver a probar.
5. El proveedor avisa después al receptor en qué terminó el envío: `entregada` o `rebotada`.

## Qué probar

| # | Escenario | Dónde | Qué se ve |
|---|---|---|---|
| 1 | Emitir un certificado | Consola → "Emitir certificado" | El recorrido completo y el correo armado en la bandeja |
| 2 | Emitirlo por la API | Consola → "Emitir certificado por la API" | El mismo recorrido, con origen `api` |
| 3 | La acción llama dos veces a `send()` | Casilla "la acción llama dos veces a send()" | Una sola notificación; la segunda queda como duplicada |
| 4 | La acción falla a la mitad | Casilla "la acción falla a la mitad" | Ni certificado ni notificación |
| 5 | Política del cliente | Empresa Minera Los Robles → "Saludar cumpleaños"; botón "Intentar apagar lo crítico" | "No enviada: política del cliente"; el rechazo |
| 6 | Límite de frecuencia | Cuatro avisos no críticos y un certificado a la misma persona | El cuarto queda retenido; el certificado pasa |
| 7 | Caída del proveedor | "Apagar el proveedor", emitir varias, "Encender el proveedor" | Esperan, se reintenta y salen con lo crítico primero |
| 8 | Historial | Pantalla Historial | Filtros y recorridos, con no enviadas y un rebote |

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
| `app/central/` | La central: `Notification` (`define` y `send`), catálogo, despachador, políticas, canales, proveedores, receptor, auditoría y configuración | Es la única que habla con el proveedor de correo |
| `app/modulos/` | Los módulos de los equipos: sus definiciones y sus acciones de negocio | Solo usan `Notification.define` y `Notification.send` |
| `app/controllers/` | Las puertas: pantallas y API | Llaman a las acciones; nunca a `send()` |
| `test/` | Las pruebas | `test/chequeos/` revisa el código mismo: que ninguna puerta llame a `send()` y que solo el canal email hable con el proveedor |

Los valores de la central (límite de frecuencia, esperas, tiempos) están en un solo lugar:
`app/central/notification/configuracion.rb`.

## Requisitos y dónde se ve cada uno

| Req. | Qué pide | Dónde se ve |
|---|---|---|
| R1 | Punto único de envío: nadie habla con el proveedor fuera de la central | Prueba automática 28, que revisa el código |
| R2 | Sin duplicados | Consola: emitir con la casilla "la acción llama dos veces a send()". Pruebas 6 a 10 |
| R3 | Frecuencia máxima para lo no crítico | Consola: cuatro avisos no críticos y uno crítico a la misma persona. Pruebas 19, 20, 32 y 33 |
| R4 | Importancia declarada | Catálogo. Pruebas 1 y 2 |
| R5 | Política de envío configurable por cliente | Consola: un aviso opcional en Minera Los Robles. Prueba 17 |
| R6 | Lo crítico siempre tiene canal | Consola: botón "Intentar apagar lo crítico". Prueba 18 |
| R7 | Canales extensibles sin tocar definiciones | Prueba 29, con un canal de prueba |
| R8 | Definición única, validada | Catálogo: botón "Probar una definición inválida". Pruebas 1 a 3 |
| R9 | Se dispara desde la acción de negocio, igual por web, API o carga masiva | Consola: emitir por la pantalla y por la API. Pruebas 24 y 27. Hay dos puertas (web y API); la carga masiva no se construye |
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
| Varias máquinas toman pendientes; si una cae, otra sigue | Un solo despachador |
| Reintentos con esperas de minutos | Esperas de 5, 10 y 20 segundos |
| Reintentos "con esperas cada vez más largas" (no dice si por correo o por proveedor) | Por canal: se prueba con el pendiente más crítico y, cuando pasa, salen todos por importancia |
| N y período del límite de frecuencia, pendientes | 3 no críticas por persona y canal en 24 h; cuenta la decisión de enviar |
| Varios canales y respaldo para lo crítico (cuando exista un segundo canal) | Un solo canal por envío |
| Auditoría a escala (R11) | No se demuestra |
| Tres puertas de entrada: web, API y carga masiva (R9) | Dos: web y API |
| Quién originó la solicitud (R10) | Se anota la notificación, que identifica al módulo dueño, y la puerta (web, api o interno) |
| Tiempos de salida: lo crítico en menos de 1 minuto, lo demás en menos de 15 (R13) | No se miden; solo se muestra el orden |
| Envío doble si la app cae justo después de que el proveedor acepta (fuera del documento) | Puede ocurrir; no se trata |
| Autenticación de la API | La API de ejemplo no pide credenciales |
| Aviso de SendGrid por la red, firmado | El proveedor simulado llama al receptor por código; sin firma |
| Auditoría separada por día, 90 días, archivo a S3 | Una tabla, sin archivo |
| La aplicación no tiene permiso para modificar ni borrar | La base rechaza UPDATE y DELETE sobre la auditoría con disparadores |
| Contador de frecuencia propio | Se cuenta sobre la auditoría |
| Cada empresa ve solo lo suyo (autenticación) | Sin login; la empresa se elige en un filtro obligatorio |
| Clave única (el documento no fija formato) | Texto legible, sin resumir |
| Resumen para lo excedente (opcional) | Solo retener |
| Chequeos automáticos en la revisión de código | Dos pruebas automáticas que revisan el código |
| Pantalla de políticas fuera de alcance | Políticas sembradas; un botón solo para mostrar el rechazo |
| SQLite admite un solo escritor a la vez (propio de la demo) | No se muestran varias máquinas tomando pendientes |

## Riesgos declarados

- **Envío doble.** Si la app se cae justo después de que el proveedor acepta un correo y
  antes de guardarlo, ese correo puede salir dos veces. La demo no lo trata.
- **Un solo escritor.** SQLite admite un solo escritor a la vez, así que la demo no muestra
  varias máquinas tomando pendientes.
- **Sin login.** Cualquiera con el link puede usar la demo y la API de ejemplo.
