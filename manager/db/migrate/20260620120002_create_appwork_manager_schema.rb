class CreateAppworkManagerSchema < ActiveRecord::Migration[8.1]
  def change
    # NOTE: no `status` column on any spine table. Every spine model is a Chorus
    # workable declaring `okf_frontmatter :status`, whose accessor lives in the
    # OKF concept's custom_frontmatter and would SHADOW a DB column here (an
    # unreachable, silent-divergence trap). A queryable status column, if ever
    # needed, returns as a deliberate event-stream projection.
    # See doc/adrs/0001-status-event-sourcing.md.
    create_table :appwork_manager_strategies do |t|
      t.string :name, null: false
      t.text :description
      t.timestamps
    end

    create_table :appwork_manager_goals do |t|
      t.references :strategy, null: false, foreign_key: { to_table: :appwork_manager_strategies }
      t.string :name, null: false
      t.text :description
      t.timestamps
    end

    create_table :appwork_manager_projects do |t|
      t.references :goal, null: false, foreign_key: { to_table: :appwork_manager_goals }
      t.string :name, null: false
      t.string :slug
      t.text :description
      # NOTE: no `status` column. Project is a Chorus workable; status lives in
      # the OKF concept's custom_frontmatter via Appwork::Chorus::Workable#status, and a
      # DB column here would be SHADOWED by that accessor (unreachable, a silent
      # divergence trap). A queryable status column, if ever needed, returns as a
      # deliberate event-stream projection. See doc/adrs/0001-status-event-sourcing.md.
      t.timestamps
    end

    # tickets.agent_id references a CHORUS agent. Because chorus and
    # manager tables are colocated in one database, this is a real,
    # enforced FK to appwork_chorus_agents (org → chorus, the allowed direction).
    create_table :appwork_manager_tickets do |t|
      t.references :project, null: false, foreign_key: { to_table: :appwork_manager_projects }
      t.references :agent,   null: true,  foreign_key: { to_table: :appwork_chorus_agents }
      t.string :title, null: false
      t.text :description
      # NOTE: no `status` column — same reason as appwork_manager_projects above.
      # Ticket is a Chorus workable; status lives in concept custom_frontmatter.
      t.integer :position
      t.timestamps
    end
  end
end
