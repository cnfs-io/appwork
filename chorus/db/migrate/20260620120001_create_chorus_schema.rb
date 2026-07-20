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

    # RoleSkill: the AgentRole <-> Skill join (plan 010 §3). A real join model, not
    # HABTM, because attributes are likely (`required`, `position`, ordering) and
    # adding them later to a HABTM table means a migration AND a new model. Carries
    # no attributes yet beyond the two FKs; a role's skills are unique on the pair.
    create_table :chorus_role_skills do |t|
      t.references :agent_role, null: false, foreign_key: { to_table: :chorus_agent_roles }
      t.references :skill,      null: false, foreign_key: { to_table: :chorus_skills }
      t.timestamps

      t.index [ :agent_role_id, :skill_id ], unique: true
    end

    # AgentAdapter is an STI base (plan 007 took the fallback plan 001 parked):
    # per-runtime subclasses (ClaudeCode, OpenCode) are ADAPTERS carrying the
    # invocation behavior a Concept cannot express (different binary/argv/parsing).
    # `type` is the Rails STI discriminator — distinct from CnfsOkf::Concept#type (an
    # OKF frontmatter field), which the two never conflate.
    create_table :chorus_agent_adapters do |t|
      t.string :type                      # STI discriminator (Chorus::AgentAdapter::ClaudeCode, ...)
      t.string :name, null: false
      t.timestamps

      t.index :type
    end

    create_table :chorus_agents do |t|
      t.references :agent_adapter, null: true, foreign_key: { to_table: :chorus_agent_adapters }
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

    # Plan (plan 010 §5): an OKF-backed markdown document an agent writes into its
    # workspace's doc/ bundle. The row claims OWNERSHIP of the synced Concept
    # (has_one_okf :concept); narrative content lives in the Concept, never a column
    # here. `name` is the plan's human label; the agent × workspace it belongs to
    # are real FKs (the Planner that populates this is a later step).
    create_table :chorus_plans do |t|
      t.references :workspace, null: false, foreign_key: { to_table: :chorus_workspaces }
      t.references :agent,     null: false, foreign_key: { to_table: :chorus_agents }
      t.string     :name,      null: false
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

    # --- 007 agent invocation seam -------------------------------------------
    # AgentRole: an ORG ROLE — the HR-shaped job a participant holds ("project
    # manager", "swe"), with a charter and skills. The org-position Role left in 004
    # because IAM owned Role; IAM's Role has since narrowed to authorization only, so
    # the HR role belongs here (plan 010 §1). Its charter is `has_one_okf :concept`
    # (polymorphic, `as: :owner`, so no FK column here); its skills attach through
    # the chorus_role_skills join. Scaled back in 010 §2 from the speculative
    # "capability loadout" (skills + view_ports + corpus window). (Named AgentRole,
    # not Role: a host may have IAM::Role in scope.)
    create_table :chorus_agent_roles do |t|
      t.string :name, null: false
      t.text   :description
      t.timestamps
    end

    # SkillRequirement: a role's durable, catalog-naive requirement — a skill named
    # by STABLE identity (name/slug), NOT an FK into the clobber-refreshed catalog.
    # A Chorus::SkillResolver maps these names -> concrete catalog rows/git sources
    # at equip time (§4); pinning a durable AgentRole to the volatile catalog would
    # let a refresh break role definitions.
    create_table :chorus_skill_requirements do |t|
      t.references :agent_role, null: false, foreign_key: { to_table: :chorus_agent_roles }
      t.string     :name, null: false   # stable skill identity ("web-design-guidelines")
      t.string     :slug                 # optional normalized key
      t.timestamps

      t.index [ :agent_role_id, :name ], unique: true
    end

    # Result: the durable outcome of an invocation (AR-backed, persisted on EVERY
    # run — live or dry). Interface is modeled on ActiveModel::Errors (keyed
    # messages that merge), but the backing is this table so an evaluator can later
    # append to the SAME record and score the SAME artifact (§5). `success` is the
    # recorded outcome; `agents_live`/`skills_live` mark which switches were in
    # effect (§8); `recorded_argv` is the claude/npx argv that ran (or WOULD have
    # run, in dry mode), so a dry run is fully inspectable; `messages` is the keyed
    # bag (category -> [msg]).
    create_table :chorus_results do |t|
      t.references :artifact,  null: true, foreign_key: { to_table: :chorus_artifacts }
      t.references :workspace, null: true, foreign_key: { to_table: :chorus_workspaces }
      t.boolean :success                  # recorded outcome (nil = fall back to empty?)
      t.boolean :agents_live              # execution-mode marker: was the agent exec live?
      t.boolean :skills_live              # execution-mode marker: was the npx install live?
      t.json    :recorded_argv, default: [] # [{ "phase" => "equip"|"invoke", "argv" => [...] }, ...]
      t.json    :messages,      default: {} # ActiveModel::Errors-shaped bag: { category => [msg] }
      t.timestamps
    end
  end
end
