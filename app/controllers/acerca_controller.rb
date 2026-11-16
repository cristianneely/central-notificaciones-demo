# Acerca (/acerca): qué es esta demo, en qué se simplificó y dónde se ve cada requisito.
class AcercaController < ApplicationController
  def index
    @simplificaciones = Demo::Declaraciones::SIMPLIFICACIONES
    @requisitos = Demo::Declaraciones::REQUISITOS
  end
end
