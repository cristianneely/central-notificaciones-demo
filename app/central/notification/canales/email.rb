class Notification
  module Canales
    # El canal email. Es el único lugar del código que habla con el proveedor de
    # correo (R1): nadie más puede enviar un correo sin pasar por la central.
    class Email < Base
      include ERB::Util

      def nombre
        "email"
      end

      # El dato de la persona que este canal necesita para entregar.
      def contacto
        :correo
      end

      # Piezas → correo. El título es el asunto y el encabezado; el resumen, la vista
      # previa que muestra la bandeja; lo demás va en HTML: párrafos, negrita para lo
      # destacado, viñetas, imagen y botón. Va también una versión en texto plano, para
      # los programas de correo que no muestran HTML. El email sabe dibujar todas las
      # piezas: no degrada ninguna.
      def adaptar(contenido)
        {
          asunto: contenido.titulo,
          vista_previa: contenido.resumen,
          html: html(contenido),
          texto: texto(contenido)
        }
      end

      # El proveedor tiene una sola operación: entregar. Hoy es el simulado; un
      # adaptador de un proveedor real se cambiaría en esta línea, sin tocar el resto.
      def entregar_al_proveedor(mensaje, pendiente:, para:)
        Proveedores::Simulado.entregar(
          mensaje.merge(para: para, solicitud_id: pendiente.solicitud_id, usuario_id: pendiente.usuario_id)
        )
      end

      private

      # Todo dato se escapa: un nombre con "<" o "&" se ve tal cual y no rompe el correo.
      # La vista previa va oculta al inicio: los programas de correo la muestran en la
      # bandeja junto al asunto.
      def html(contenido)
        vista_previa = %(<span class="vista-previa" style="display:none">#{h contenido.resumen}</span>)
        vista_previa + contenido.piezas.map { |pieza| a_html(pieza) }.join
      end

      def a_html(pieza)
        case pieza[:tipo]
        when :titulo then "<h1>#{h pieza[:texto]}</h1>"
        when :parrafo then "<p>#{h pieza[:texto]}</p>"
        when :destacado then "<p><strong>#{h pieza[:texto]}</strong></p>"
        when :lista then "<ul>#{pieza[:items].map { |item| "<li>#{h item}</li>" }.join}</ul>"
        when :imagen then %(<img src="#{h pieza[:url]}" alt="#{h pieza[:alt]}">)
        when :boton then %(<p><a class="boton" href="#{h pieza[:link]}">#{h pieza[:texto]}</a></p>)
        else "" # el resumen ya va como vista previa
        end
      end

      def texto(contenido)
        contenido.piezas.filter_map { |pieza| a_texto(pieza) }.join("\n\n")
      end

      def a_texto(pieza)
        case pieza[:tipo]
        when :titulo, :parrafo, :destacado then pieza[:texto]
        when :lista then pieza[:items].map { |item| "- #{item}" }.join("\n")
        when :imagen then "#{pieza[:alt]}: #{pieza[:url]}"
        when :boton then "#{pieza[:texto]}: #{pieza[:link]}"
        end
      end
    end
  end
end
