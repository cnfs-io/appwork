class CreateChorusRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :chorus_roles do |t|
      t.references :organization, null: false, foreign_key: { to_table: :chorus_organizations }
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
  end
end
