class CreateChorusSchema < ActiveRecord::Migration[8.1]
  def change
    # Workspace occupies a polymorphic `workable` (added after create so the
    # column set reads together). Org models (Strategy/Goal/Project/Issue) and
    # Role left Chorus in plan 004; the workable target lives in the org gem.
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
      t.references :agent_profile, null: true, foreign_key: { to_table: :chorus_agent_profiles }
      t.string :name, null: false
      t.timestamps
    end

    add_reference :chorus_workspaces, :workable, polymorphic: true, null: true

    create_table :chorus_artifacts do |t|
      t.references :workspace, null: false, foreign_key: { to_table: :chorus_workspaces }
      t.string :name, null: false
      t.string :kind
      t.string :locator
      t.text :description
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

    # --- 004 skill catalog (plumbing only) -----------------------------------
    # CatalogSkill: a local, refreshable MIRROR of a skill as it exists upstream
    # (npx / skills.sh). Truth lives upstream; this table is a join/query cache
    # populated by the npx wrapper. The natural key is [resource, skill_name]
    # (skill_name nullable to represent a whole-repo entry). Refresh clobbers —
    # nothing tenant-authored lives here.
    create_table :chorus_catalog_skills do |t|
      t.string   :resource,     null: false  # `owner/repo` upstream identifier
      t.string   :skill_name                 # skill within the repo; nil = whole-repo entry
      t.text     :description                # upstream description (the searchable field)
      t.integer  :install_count              # upstream popularity signal
      t.json     :repo_topics                # raw upstream topic strings, un-normalized (folksonomy, NOT taxonomy)
      t.datetime :synced_at                  # last mirror refresh
      t.timestamps

      t.index [ :resource, :skill_name ], unique: true
    end

    # Curation: chorus.org's central verdict about a skill, distributed as a YAML
    # whitelist and loaded read-only into each tenant's DB. Three-state reputation
    # by ROW PRESENCE: absent = no verdict (unknown); 0 = reviewed, trash/dangerous
    # (bottom of scale, NOT a hard block); 1..100 = graded quality. Joins CatalogSkill
    # on the natural key [resource, skill_name] — different source, different cadence,
    # so either side may exist without the other.
    create_table :chorus_curations do |t|
      t.string  :resource,   null: false   # `owner/repo` (join key, mirrors CatalogSkill)
      t.string  :skill_name                # join key; nil = whole-repo verdict
      t.integer :reputation                # chorus.org's graded score, 0..100
      t.timestamps

      t.index [ :resource, :skill_name ], unique: true
    end

    # Taxonomy: a first-class, queryable category dimension. Owned by neither the
    # catalog nor curation — it stands alone and is (in a later plan) morphed from
    # OKF Concepts, reconciled against the stable `slug`. `parent_id` allows a
    # shallow area -> sub-category hierarchy; no hierarchy logic is built beyond
    # the self-association. Durable: categories persist across scans.
    create_table :chorus_taxonomies do |t|
      t.string  :name,   null: false   # human label ("marketing", "ruby-on-rails")
      t.string  :slug,   null: false   # normalized identifier; the key a Concept-scan reconciles against
      t.integer :parent_id             # self-referential; nil = top-level area
      t.timestamps

      t.index :slug, unique: true
      t.index :parent_id
    end
    add_foreign_key :chorus_taxonomies, :chorus_taxonomies, column: :parent_id

    # SkillCategorization: the bare CatalogSkill <-> Taxonomy join. v1 is two FKs
    # and a unique pair index — NO provenance column (who assigned the tag is a
    # policy question, deferred; see `# 004 deferred:` in the models).
    create_table :chorus_skill_categorizations do |t|
      t.references :catalog_skill, null: false, foreign_key: { to_table: :chorus_catalog_skills }
      t.references :taxonomy,      null: false, foreign_key: { to_table: :chorus_taxonomies }
      t.timestamps

      t.index [ :catalog_skill_id, :taxonomy_id ], unique: true
    end
  end
end
