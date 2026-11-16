require "test_helper"

# La base de producción es un archivo SQLite dentro de la app. En Render se pierde al dormir
# o redesplegar, y la app vuelve a los datos semilla (supuesto de hosting de la spec).
# Sin este archivo asignado, la app no arranca en producción.
class BaseDeProduccionTest < ActiveSupport::TestCase
  test "producción tiene un archivo de base asignado" do
    config = ActiveRecord::Base.configurations.configs_for(env_name: "production").first

    assert_equal "storage/production.sqlite3", config.database
  end
end
