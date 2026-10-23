class CreateAppworkChatterConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :appwork_chatter_conversations do |t|
      t.integer :kind, null: false, default: 0
      t.string :name

      t.timestamps
    end
  end
end
