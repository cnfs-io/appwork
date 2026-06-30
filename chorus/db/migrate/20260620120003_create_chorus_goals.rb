class CreateChorusGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :chorus_goals do |t|
      t.references :strategy, null: false, foreign_key: { to_table: :chorus_strategies }
      t.string :name, null: false
      t.text :description
      t.string :status

      t.timestamps
    end
  end
end
