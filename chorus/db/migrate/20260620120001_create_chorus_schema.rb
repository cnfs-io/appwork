class CreateChorusSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :chorus_strategies do |t|
      t.string :name, null: false
      t.text :description
      t.string :status
      t.timestamps
    end

    create_table :chorus_goals do |t|
      t.references :strategy, null: false, foreign_key: { to_table: :chorus_strategies }
      t.string :name, null: false
      t.text :description
      t.string :status
      t.timestamps
    end

    create_table :chorus_roles do |t|
      t.string :name, null: false
      t.text :description
      t.timestamps
    end

    # Workspaces created before projects so we can add active_project_id after.
    create_table :chorus_workspaces do |t|
      t.string :name, null: false
      t.text :description
      t.timestamps
    end

    create_table :chorus_skills do |t|
      t.string :name, null: false
      t.timestamps
    end

    create_table :chorus_agent_profiles do |t|
      t.string :name, null: false
      t.timestamps
    end

    create_table :chorus_agents do |t|
      t.references :role, null: true, foreign_key: { to_table: :chorus_roles }
      t.references :agent, null: true, foreign_key: { to_table: :agent_profiles }
      t.string :name, null: false
      t.timestamps
    end

    create_table :chorus_projects do |t|
      t.references :goal, null: false, foreign_key: { to_table: :chorus_goals }
      t.string :name, null: false
      t.string :slug
      t.text :description
      t.string :status
      t.timestamps
    end

    add_reference :chorus_workspaces, :active_project,
      null: true,
      foreign_key: { to_table: :chorus_projects }

    create_table :chorus_artifacts do |t|
      t.references :workspace, null: false, foreign_key: { to_table: :chorus_workspaces }
      t.string :name, null: false
      t.string :kind
      t.string :locator
      t.text :description
      t.timestamps
    end

    create_table :chorus_issues do |t|
      t.references :project, null: false, foreign_key: { to_table: :chorus_projects }
      t.references :agent,   null: true,  foreign_key: { to_table: :chorus_agents }
      t.string :title, null: false
      t.text :description
      t.string :status
      t.integer :position
      t.timestamps
    end

    # Source: a managed origin (git repo, S3 prefix, NFS mount) cloned/synced to
    # a path on disk. STI on `type`; shared/queryable fields are real columns,
    # per-kind config lives in the serialized `settings` bag. Account-scoped by
    # tenancy (physical DB per Account), so no owner column here yet — the
    # Workspace lease/claim relationship is deferred to PHASE-B.
    create_table :chorus_sources do |t|
      t.string   :type,       null: false   # STI discriminator (Chorus::Source::Git, ...)
      t.string   :resource,   null: false   # origin locator: repo URL / bucket / mount spec
      t.string   :path                      # absolute path the origin is materialized to
      t.string   :ref                       # last-synced watermark: commit SHA / etag / mtime
      t.datetime :synced_at                 # when the last successful sync completed
      t.string   :digest                    # content fingerprint for drift detection
      t.text     :settings                  # YAML-serialized per-kind config (branch, bucket, ...)
      t.timestamps

      t.index :type
    end

    # ExternalAccount: a third-party service account a tenant holds (GitHub org,
    # GitLab group, AWS account, GCP project). STI on `type`; `name` is the account
    # identifier (e.g. the GitHub org login); per-vendor config lives in the
    # serialized `settings` bag. Account-scoped by tenancy (physical DB per Account),
    # so no owner column. Only the GitHub kind acts today (creates repos).
    create_table :chorus_external_accounts do |t|
      t.string :type,     null: false   # STI discriminator (Chorus::ExternalAccount::GitHub, ...)
      t.string :name,     null: false   # account identifier: github org login / aws account label / ...
      t.text   :settings                # YAML-serialized per-vendor config bag
      t.timestamps

      t.index [ :type, :name ], unique: true
    end
  end
end
