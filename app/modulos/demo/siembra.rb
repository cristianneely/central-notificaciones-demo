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
      datos_base unless Empresa.exists?
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
  end
end
