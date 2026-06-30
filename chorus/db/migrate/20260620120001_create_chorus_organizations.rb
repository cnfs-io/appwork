class CreateChorusOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :chorus_organizations do |t|
      t.string :name, null: false
      t.string :slug
      t.text :description

      t.timestamps
    end

    add_index :chorus_organizations, :slug, unique: true
  end
end
