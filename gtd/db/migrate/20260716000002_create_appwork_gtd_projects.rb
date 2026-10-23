class CreateAppworkGtdProjects < ActiveRecord::Migration[8.1]
  def change
    # A GTD project groups actions. Concept-owning (its own title/notes live in an
    # owned Appwork::Okf::Concept on disk); `name` is a plain fallback label.
    create_table :appwork_gtd_projects do |t|
      t.string :name

      t.timestamps
    end
  end
end
