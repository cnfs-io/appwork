class CreateAppworkGtdContexts < ActiveRecord::Migration[8.1]
  def change
    # A GTD context (@home, @work, @calls) — a small grouping label. The context
    # BOARD is a pure view (ADR 0005): dragging never reassigns context, so this
    # table stays deliberately minimal.
    create_table :appwork_gtd_contexts do |t|
      t.string :name

      t.timestamps
    end
  end
end
