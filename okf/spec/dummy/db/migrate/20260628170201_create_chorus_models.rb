class CreateChorusModels < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :title
      t.text   :body
      t.timestamps
    end

    create_table :strategies do |t|
      t.references :account, null: false, foreign_key: true
      t.string :title
      t.text   :body
      t.timestamps
    end

    create_table :goals do |t|
      t.references :strategy, null: false, foreign_key: true
      t.string :title
      t.text   :body
      t.timestamps
    end
  end
end
