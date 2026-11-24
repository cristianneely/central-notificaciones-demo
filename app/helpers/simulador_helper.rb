module SimuladorHelper
  NOMBRES_CANALES = { "email" => "Email", "slack" => "Slack", "whatsapp" => "WhatsApp", "sms" => "SMS", "push" => "Push" }.freeze

  # Qué hace cada canal con cada pieza: la tabla de la sección 2.1.5, en el orden del
  # vocabulario y de los canales del simulador. Lo que un canal degrada lo declara también
  # en su DEGRADA; esta tabla es la vista completa, para leerla de una vez.
  TABLA_PIEZAS = {
    titulo: { "email" => "Asunto y encabezado", "slack" => "Encabezado", "whatsapp" => "Primera línea en negrita",
              "sms" => "Se omite", "push" => "Título de la notificación" },
    resumen: { "email" => "Vista previa en la bandeja", "slack" => "Texto del aviso", "whatsapp" => "Se omite",
               "sms" => "El mensaje", "push" => "El texto" },
    parrafo: { "email" => "Párrafo en HTML", "slack" => "Texto", "whatsapp" => "Texto",
               "sms" => "Se omite", "push" => "Se omite" },
    destacado: { "email" => "Negrita", "slack" => "Negrita", "whatsapp" => "Negrita",
                 "sms" => "Se omite", "push" => "Se omite" },
    lista: { "email" => "Viñetas", "slack" => "Viñetas", "whatsapp" => "Líneas con guion",
             "sms" => "Se omite", "push" => "Se omite" },
    imagen: { "email" => "Imagen", "slack" => "Imagen", "whatsapp" => "Imagen adjunta",
              "sms" => "Se omite", "push" => "Imagen al expandir" },
    boton: { "email" => "Botón", "slack" => "Botón", "whatsapp" => "Botón de la plantilla; sin plantilla, link",
             "sms" => "Link corto", "push" => "Tocar la notificación abre el link" },
    personas: { "email" => "Fila de fotos con el nombre debajo", "slack" => "Foto chica y nombre por persona",
                "whatsapp" => "Nombres en el texto; sin imagen, adjunta la foto de la primera", "sms" => "Se omite",
                "push" => "Sin imagen, la foto de la primera" }
  }.freeze

  # Qué permite cada canal, en una línea.
  PERMITE = {
    "email" => "Todas las piezas, en HTML y en texto plano",
    "slack" => "Todas las piezas, con el formato de Slack",
    "whatsapp" => "Texto con negrita y una imagen; el botón, solo con plantilla aprobada",
    "sms" => "Solo texto: 160 caracteres como máximo",
    "push" => "Un título, una o dos líneas y una imagen"
  }.freeze

  NOMBRES_PIEZAS = { titulo: "Título", resumen: "Resumen", parrafo: "Párrafo", destacado: "Destacado",
                     lista: "Lista", imagen: "Imagen", boton: "Botón", personas: "Personas" }.freeze

  # Cómo se llama, para una persona, el dato de contacto que pide cada canal.
  CONTACTOS = { slack: "su usuario de Slack", telefono: "su teléfono", dispositivo: "un dispositivo registrado" }.freeze

  # A quién iría el mensaje de un canal: el contacto leído de la base, o qué dato pediría.
  def para_del_canal(canal)
    return "Para: #{canal[:para]}" if canal[:para]
    return "Sin correo: el email no se enviaría" if canal[:contacto] == :correo

    "Pediría #{CONTACTOS.fetch(canal[:contacto])} (:#{canal[:contacto]}): las personas de la demo no lo tienen"
  end

  # Lo que recibiría el proveedor de cada canal, tal cual.
  def mensaje_crudo(canal, mensaje)
    case canal
    when "email"
      "Asunto: #{mensaje[:asunto]}\nVista previa: #{mensaje[:vista_previa]}\n\n" \
        "--- HTML ---\n#{mensaje[:html]}\n\n--- Texto plano ---\n#{mensaje[:texto]}"
    when "sms" then mensaje[:texto]
    else JSON.pretty_generate(mensaje)
    end
  end

  # El correo completo, para mostrarlo dentro de un iframe aislado, como lo abriría un
  # programa de correo.
  def correo_srcdoc(html)
    estilo = "body{margin:0;padding:16px;font:15px/1.5 Georgia,serif;color:#1f2328}" \
             "h1{font-size:20px;margin:0 0 12px}img{max-width:100%;border-radius:6px}" \
             "a.boton{display:inline-block;padding:8px 16px;background:#1f6f5c;color:#fff;" \
             "border-radius:6px;text-decoration:none;font-family:system-ui,sans-serif}"
    "<!doctype html><html><head><meta charset=\"utf-8\"><style>#{estilo}</style></head><body>#{html}</body></html>"
  end

  # Texto en el formato de Slack → HTML. Slack ya escapó &, < y >; solo se convierte la
  # negrita y los saltos de línea.
  def mrkdwn_a_html(texto)
    sanitize(texto.gsub(/\*([^*\n]+)\*/, '<strong>\1</strong>').gsub("\n", "<br>"), tags: %w[strong br])
  end

  # Texto de WhatsApp → HTML: se escapa todo y después se dibuja la *negrita*.
  def whatsapp_a_html(texto)
    h(texto).gsub(/\*([^*\n]+)\*/, '<strong>\1</strong>').gsub("\n", "<br>").html_safe
  end
end
