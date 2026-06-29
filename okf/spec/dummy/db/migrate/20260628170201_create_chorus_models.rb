class CreateChorusModels < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :title
      t.text   :body
      t.timestamps
    end

    create_table :strategies do |t|
      t.references :organization, null: false, foreign_key: true
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

    create_table :projects do |t|
      t.references :goal, null: false, foreign_key: true
      t.string :title
      t.text   :body
      t.timestamps
    end

    create_table :issues do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title
      t.text   :body
      t.timestamps
    end
  end
end
