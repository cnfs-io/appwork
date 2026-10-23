# Dummy-app-only table backing WorkableDummy, the isolated test subject for the
# Appwork::Chorus::Workable concern. Lives in the dummy's own db/migrate (not the engine
# schema) so it never reaches a real Chorus database.
class CreateWorkableDummies < ActiveRecord::Migration[8.1]
  def change
    create_table :workable_dummies do |t|
      t.string :name
      t.timestamps
    end
  end
end
