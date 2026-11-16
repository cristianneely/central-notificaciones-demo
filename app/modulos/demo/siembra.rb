module Demo
  # Los datos semilla de la demo. Todo es ficticio.
  module Siembra
    EMPRESAS = { 1 => "Andes Capacitación", 2 => "Minera Los Robles", 3 => "Clínica Austral" }.freeze

    # Ocho personas por empresa: [nombre, correo]. Los ids van corridos: 1 a 8 Andes,
    # 9 a 16 Minera, 17 a 24 Clínica.
    PERSONAS = {
      1 => [
        ["Ana Soto", "ana.soto@ejemplo.test"],
        ["Bruno Díaz", "bruno.diaz@ejemplo.test"],
        ["Carla Muñoz", "carla.munoz@ejemplo.test"],
        ["Diego Rojas", "diego.rojas@ejemplo.test"],
        ["Elena Pérez", "elena.perez@ejemplo.test"],
        ["Fabián Lagos (rebota)", "fabian.lagos@rebota.test"], # el proveedor avisa un rebote
        ["Gloria Vera (correo inválido)", "correo-invalido"],    # el proveedor rechaza ese correo
        ["Hugo Pinto (sin correo)", ""]                          # la central no tiene a dónde enviar
      ],
      2 => [
        ["Inés Castro", "ines.castro@ejemplo.test"],
        ["Javier Mora", "javier.mora@ejemplo.test"],
        ["Karen Fuentes", "karen.fuentes@ejemplo.test"],
        ["Luis Bravo", "luis.bravo@ejemplo.test"],
        ["Marta Silva", "marta.silva@ejemplo.test"],
        ["Nicolás Reyes", "nicolas.reyes@ejemplo.test"],
        ["Olga Navarro", "olga.navarro@ejemplo.test"],
        ["Pablo Herrera", "pablo.herrera@ejemplo.test"]
      ],
      3 => [
        ["Rosa Molina", "rosa.molina@ejemplo.test"],
        ["Sergio Campos", "sergio.campos@ejemplo.test"],
        ["Teresa Vidal", "teresa.vidal@ejemplo.test"],
        ["Ulises Parra", "ulises.parra@ejemplo.test"],
        ["Valeria Ortiz", "valeria.ortiz@ejemplo.test"],
        ["Walter Guzmán", "walter.guzman@ejemplo.test"],
        ["Ximena Cortés", "ximena.cortes@ejemplo.test"],
        ["Yolanda Ríos (rebota)", "yolanda.rios@rebota.test"]
      ]
    }.freeze

    # Se llama al preparar la base (db/seeds.rb): siembra solo si no hay empresas.
    def self.sembrar_si_vacia
      ejecutar unless Empresa.exists?
    end

    # La siembra completa: los datos base y un historial de ejemplo.
    def self.ejecutar
      # Lo sembrado no entró por ninguna puerta: queda con origen "interno".
      Notification::Contexto.set(origen: "interno") do
        datos_base
        historial_de_ejemplo
      end
    end

    # Empresas, personas y la política propia de Minera Los Robles.
    def self.datos_base
      EMPRESAS.each { |id, nombre| Empresa.create!(id: id, nombre: nombre) }

      id = 0
      PERSONAS.each do |empresa_id, personas|
        personas.each do |nombre, email|
          Usuario.create!(id: id += 1, empresa_id: empresa_id, nombre: nombre, email: email)
        end
      end

      # Minera Los Robles apagó el email para lo opcional (R5).
      Notification::PoliticaCliente.create!(
        empresa_id: 2, importancia: "opcional", canal: "email", habilitado: false
      )
    end

    # Historial de ejemplo, para que la demo no parta vacía. No son filas escritas a
    # mano: se ejecutan las acciones de negocio y se deja trabajar a la central.
    # Andes Capacitación (empresa 1) queda sin historial: es la empresa para probar en vivo.
    def self.historial_de_ejemplo
      rosa, sergio, yolanda = Usuario.find(17), Usuario.find(18), Usuario.find(24) # Clínica Austral
      ines = Usuario.find(9)                                                        # Minera Los Robles

      # 1. Un certificado que llega bien → entregada.
      emitir_certificado(rosa, "Excel básico")
      # 2. Un certificado a un correo que rebota → rebotada.
      emitir_certificado(yolanda, "Excel básico")
      # 3. La acción llama dos veces a send() → una entregada y una duplicada.
      emitir_certificado(rosa, "Excel avanzado", llamar_dos_veces: true)

      # 4. Cuatro avisos no críticos a la misma persona → tres entregadas y el cuarto retenido.
      pedido = { empresa_id: sergio.empresa_id, usuario_id: sergio.id }
      Cursos::EnviarRecordatorio.ejecutar(**pedido, curso: "Excel básico")
      despachar_todo
      Cursos::EnviarRecordatorio.ejecutar(**pedido, curso: "Excel avanzado")
      despachar_todo
      Cursos::EnviarEncuesta.ejecutar(**pedido, curso: "Excel básico")
      despachar_todo
      Personas::SaludarCumpleanos.ejecutar(**pedido)
      despachar_todo

      # 5. Un aviso opcional en una empresa que lo apagó → no enviada por política del cliente.
      Personas::SaludarCumpleanos.ejecutar(empresa_id: ines.empresa_id, usuario_id: ines.id)
      despachar_todo
    end

    def self.emitir_certificado(persona, curso, **opciones)
      Certificados::EmitirCertificado.ejecutar(
        empresa_id: persona.empresa_id, usuario_id: persona.id, curso: curso, **opciones
      )
      despachar_todo
    end

    # Hace de inmediato lo que el hilo en segundo plano haría con el tiempo: despacha
    # hasta no dejar pendientes y entrega los avisos del proveedor sin esperar los 2 s.
    def self.despachar_todo
      10.times do
        break unless Notification::Pendiente.exists?

        Notification::Despachador.vuelta
      end
      Notification::Proveedores::Simulado.enviar_avisos(sin_demora: true)
    end

    private_class_method :emitir_certificado, :despachar_todo
  end
end
