class CreateGtdProjects < ActiveRecord::Migration[8.1]
  def change
    # A GTD project groups actions. Concept-owning (its own title/notes live in an
    # owned CnfsOkf::Concept on disk); `name` is a plain fallback label.
    create_table :gtd_projects do |t|
      t.string :name

      t.timestamps
    end
  end
end
