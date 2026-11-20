# El módulo de cursos. Los cursos de la demo son una lista fija.
module Cursos
  LISTA = ["Excel básico", "Excel avanzado", "Tablas dinámicas", "Power BI inicial"].freeze

  # La portada de un curso: una imagen propia de la demo por curso de la lista, y una
  # genérica para cualquier otro. Es la que lleva el aviso del certificado.
  def self.imagen(curso)
    LISTA.include?(curso) ? "/cursos/#{curso.parameterize}.svg" : "/cursos/curso.svg"
  end
end
