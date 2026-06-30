class CreateChorusAgents < ActiveRecord::Migration[8.1]
  def change
    create_table :chorus_agents do |t|
      t.references :organization, null: false, foreign_key: { to_table: :chorus_organizations }
      t.references :role, null: true, foreign_key: { to_table: :chorus_roles }
      t.string :name, null: false
      t.string :kind

      t.timestamps
    end
  end
end
