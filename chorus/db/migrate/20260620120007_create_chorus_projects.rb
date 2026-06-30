class CreateChorusProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :chorus_projects do |t|
      t.references :goal, null: false, foreign_key: { to_table: :chorus_goals }
      t.string :name, null: false
      t.string :slug
      t.text :description
      t.string :status

      t.timestamps
    end

    # Workspace's active-project slot — added here, after projects exists, to
    # break the workspace<->project cycle. Nullable on purpose: a workspace may
    # sit idle with no active project.
    add_reference :chorus_workspaces, :active_project, null: true,
      foreign_key: { to_table: :chorus_projects }
  end
end
