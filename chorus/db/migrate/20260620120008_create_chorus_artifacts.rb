class CreateChorusArtifacts < ActiveRecord::Migration[8.1]
  def change
    create_table :chorus_artifacts do |t|
      t.references :workspace, null: false, foreign_key: { to_table: :chorus_workspaces }
      t.string :name, null: false
      t.string :kind
      t.string :locator
      t.text :description

      t.timestamps
    end
  end
end
