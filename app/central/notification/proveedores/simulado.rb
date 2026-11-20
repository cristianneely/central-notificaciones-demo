class Notification
  module Proveedores
    # El proveedor de correo simulado: ocupa el lugar que tendría el proveedor real.
    # No sale ningún correo: lo que "acepta" queda guardado en su bandeja, y un rato
    # después avisa al receptor en qué terminó, igual que haría el proveedor real.
    module Simulado
      ENCENDIDO = "proveedor_encendido"

      # El interruptor de la demo: apagado, el proveedor no responde (simula una caída).
      def self.encendido?
        AjusteDemo.find_by(clave: ENCENDIDO)&.valor != "no"
      end

      def self.encender
        AjusteDemo.where(clave: ENCENDIDO).delete_all
      end

      def self.apagar
        AjusteDemo.find_or_create_by!(clave: ENCENDIDO) { |ajuste| ajuste.valor = "no" }
      end

      # La única operación de un proveedor. Devuelve un Resultado.
      def self.entregar(correo)
        return Resultado.sin_respuesta unless encendido?

        # Rechaza ese correo puntual cuando la dirección no tiene arroba.
        return Resultado.rechazado("dirección inválida") unless correo[:para].to_s.include?("@")

        guardado = CorreoSimulado.create!(
          solicitud_id: correo[:solicitud_id],
          usuario_id: correo[:usuario_id],
          para: correo[:para],
          asunto: correo[:asunto],
          vista_previa: correo[:vista_previa],
          html: correo[:html],
          cuerpo: correo[:texto],
          aceptado_en: Time.current
        )
        # El id que da el proveedor: "sim-" y un número correlativo de 6 dígitos.
        guardado.update!(id_proveedor: format("sim-%06d", guardado.id))

        Resultado.aceptado(guardado.id_proveedor)
      end

      # Avisa al receptor el estado final de los correos aceptados hace 2 segundos o más:
      # "rebotado" si la dirección termina en @rebota.test, "entregado" en los demás casos.
      # Llama al receptor por código, no por la red. Devuelve cuántos avisos envió.
      def self.enviar_avisos(ahora: Time.current, sin_demora: false)
        por_avisar = CorreoSimulado.where(aviso_enviado: false)
        unless sin_demora
          por_avisar = por_avisar.where(aceptado_en: ..(ahora - Configuracion::DEMORA_AVISO_PROVEEDOR))
        end

        por_avisar.order(:id).each do |correo|
          Receptor.recibir(
            solicitud_id: correo.solicitud_id,
            usuario_id: correo.usuario_id,
            id_proveedor: correo.id_proveedor,
            estado: correo.para.end_with?("@rebota.test") ? "rebotado" : "entregado"
          )
          correo.update!(aviso_enviado: true)
        end.size
      end
    end
  end
end
