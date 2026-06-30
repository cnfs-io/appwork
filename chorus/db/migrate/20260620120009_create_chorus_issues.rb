class CreateChorusIssues < ActiveRecord::Migration[8.1]
  def change
    create_table :chorus_issues do |t|
      t.references :project, null: false, foreign_key: { to_table: :chorus_projects }
      t.references :agent, null: true, foreign_key: { to_table: :chorus_agents }
      t.string :title, null: false
      t.text :description
      t.string :status
      t.integer :position

      t.timestamps
    end
  end
end
