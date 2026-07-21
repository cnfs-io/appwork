class CreateChorusSchema < ActiveRecord::Migration[8.1]
  def change
    # Workspace occupies a polymorphic `workable` (added after create so the
    # column set reads together). Org models (Strategy/Goal/Project/Issue) and
    # Role left Chorus in plan 004; the workable target lives in the org gem.
    # Workspace (plan 011 §6): a plot of land — a role, the sources it owns, a
    # viewport, and a serial-occupancy claim. Top-level root scoped by the database;
    # `current_work_order_id` is the claim slot (one work order active at a time, set
    # by atomic conditional update), `claimed_at` its stamp. `workable` no longer
    # lives here — a workspace is a place and places have no subject; the workable
    # moved to WorkOrder (plan 011 §4).
    create_table :chorus_workspaces do |t|
      t.references :role, null: false, foreign_key: { to_table: :chorus_roles }
      t.string :name, null: false
      t.text :description
      t.bigint :current_work_order_id      # the serial-occupancy claim (FK added with chorus_work_orders)
      t.datetime :claimed_at               # when the current claim was taken
      t.timestamps

      t.index :current_work_order_id
    end

    create_table :chorus_skills do |t|
      t.string :name, null: false
      t.timestamps
    end

    # RoleSkill: the Role <-> Skill join (plan 010 §3). A real join model, not
    # HABTM, because attributes are likely (`required`, `position`, ordering) and
    # adding them later to a HABTM table means a migration AND a new model. Carries
    # no attributes yet beyond the two FKs; a role's skills are unique on the pair.
    create_table :chorus_role_skills do |t|
      t.references :role,  null: false, foreign_key: { to_table: :chorus_roles }
      t.references :skill, null: false, foreign_key: { to_table: :chorus_skills }
      t.timestamps

      t.index [ :role_id, :skill_id ], unique: true
    end

    # Agent is an STI base on its RUNTIME (plan 011 §2): the former AgentAdapter
    # collapsed into Agent because with `model` on the row every agent is a distinct
    # (runtime, model) pairing with nothing left to share. Per-runtime subclasses
    # (Chorus::Agent::ClaudeCode, Chorus::Agent::OpenCode) carry the invocation
    # behavior a Concept cannot express (binary/argv/stream parsing). `type` is the
    # Rails STI discriminator — distinct from CnfsOkf::Concept#type (an OKF
    # frontmatter field), which the two never conflate. `model` is the concrete
    # model the runtime drives ("opus-4.8", "sonnet-4.6", "nemotron").
    create_table :chorus_agents do |t|
      t.string :type              # STI discriminator (Chorus::Agent::ClaudeCode, ...)
      t.string :name, null: false
      t.string :model             # "opus-4.8", "sonnet-4.6", "nemotron"
      t.timestamps

      t.index :type
    end

    # Artifact (plan 011 §8): something a run PRODUCED, so it belongs to the Result
    # that produced it (the FK inverted — Result used to belong to Artifact).
    # Otherwise untouched this phase: no STI, no GitCommit subclass, no source FK
    # (Phase 2). `result_id` is nullable so an artifact can predate/outlive its run
    # record.
    create_table :chorus_artifacts do |t|
      t.references :result, null: true, foreign_key: { to_table: :chorus_results }
      t.string :name, null: false
      t.string :kind
      t.string :locator
      t.text :description
      t.timestamps
    end

    # Plan (plan 011 §7): an OKF-backed markdown document addressed to a role — WHO
    # should EXECUTE it — under a WorkOrder. `plan.role` differs from
    # `work_order.role` by design: each level's role is set by the level above
    # (delegation, not denormalization). The row claims OWNERSHIP of the synced
    # Concept (has_one_okf :concept); narrative content lives in the Concept, never a
    # column here.
    #
    # TRANSITIONAL: `workspace_id` still lives here and is reachable directly. It is
    # slated to drop (reachable via work_order.workspace, §7) together with the
    # deletion of Chorus::Planner in step 7 — the Planner still creates Plans by
    # workspace, so the column stays until execute! replaces it. Likewise work_order
    # and role are nullable/optional now; execute! makes them the required spine.
    create_table :chorus_plans do |t|
      t.references :work_order, null: true, foreign_key: { to_table: :chorus_work_orders }
      t.references :role,       null: true, foreign_key: { to_table: :chorus_roles }
      t.references :workspace,  null: true, foreign_key: { to_table: :chorus_workspaces }   # transitional; drops in step 7
      t.references :agent,      null: true, foreign_key: { to_table: :chorus_agents }
      t.string     :name,       null: false
      t.timestamps
    end

    # Source: a managed origin (git repo, S3 prefix, NFS mount) cloned/synced to
    # a path on disk. STI on `type`; shared/queryable fields are real columns,
    # per-kind config lives in the serialized `settings` bag. Account-scoped by
    # tenancy (physical DB per Account). `owner` is a polymorphic, optional back-ref
    # (plan 011 §6) — a Workspace owns the sources checked out into it, but a source
    # may exist unowned.
    create_table :chorus_sources do |t|
      t.references :owner,    polymorphic: true, null: true   # the Workspace (or other) that owns this checkout
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
    # Role: an ORG ROLE — the HR-shaped job a participant holds ("project manager",
    # "swe"), with a charter and skills. The org-position Role left in 004 because
    # IAM owned Role; IAM's Role has since narrowed to authorization (AAA) only, so
    # no collision remains and the defensive AgentRole prefix is dead weight (plan
    # 011 §1). Its charter is `has_one_okf :concept` (polymorphic, `as: :owner`, so
    # no FK column here); its skills attach through the chorus_role_skills join.
    create_table :chorus_roles do |t|
      t.string :name, null: false
      t.text   :description
      t.timestamps
    end

    # SkillRequirement: a role's durable, catalog-naive requirement — a skill named
    # by STABLE identity (name/slug), NOT an FK into the clobber-refreshed catalog.
    # A Chorus::SkillResolver maps these names -> concrete catalog rows/git sources
    # at equip time (§4); pinning a durable Role to the volatile catalog would let a
    # refresh break role definitions.
    create_table :chorus_skill_requirements do |t|
      t.references :role, null: false, foreign_key: { to_table: :chorus_roles }
      t.string     :name, null: false   # stable skill identity ("web-design-guidelines")
      t.string     :slug                 # optional normalized key
      t.timestamps

      t.index [ :role_id, :name ], unique: true
    end

    # WorkOrder (plan 011 §4): a job against a site. A feature request that lands
    # against a Workspace carrying the role required to execute it; an Agent is hired
    # to fill that role. The WorkOrder itself IS a document — Claude Desktop writes a
    # summary of a design conversation as markdown, which is why it carries a concept
    # (has_one_okf :concept) rather than a text column. `workable` moved here from
    # Workspace: a place has no subject, a job does. `external_session_id` is latched
    # from the first stream event (so an interrupt mid-first-turn still leaves a
    # resumable order); `--resume` is NOT wired this phase. Everything the host
    # decides (which workspace, which role, which agent) arrives fully specified
    # (§5). workable/workspace are nullable at the DB so the owning place/subject can
    # nullify on teardown, but required at the model — a valid order names both.
    create_table :chorus_work_orders do |t|
      t.references :workable,  polymorphic: true, null: true   # the occupied subject (nullify on teardown)
      t.references :workspace, null: true,  foreign_key: { to_table: :chorus_workspaces }
      t.references :role,      null: false, foreign_key: { to_table: :chorus_roles }
      t.references :agent,     null: true,  foreign_key: { to_table: :chorus_agents }
      t.string     :external_session_id     # latched from the first stream event; unused this phase
      t.string     :state                   # free-string lifecycle marker
      t.timestamps
    end

    # The Workspace serial-occupancy claim points at the active WorkOrder (§6). Added
    # here, once chorus_work_orders exists, since the column was created up top.
    add_foreign_key :chorus_workspaces, :chorus_work_orders, column: :current_work_order_id

    # Result: ONE row per invocation (plan 011 §8) — a narrow record of what a single
    # run did and what it cost, polymorphic over its resultable (a WorkOrder or Plan
    # now; a Task in Phase 2). This is a rewrite, not a rename: the old
    # ActiveModel::Errors-shaped accumulator (one durable Result per thing, kept open
    # for later contributors) is gone. A retry is a SECOND Result, so "did this
    # succeed?" is a question about `resultable.results` collectively — which is what
    # gives attempt history and retry a home. `messages` survives only as a plain
    # json diagnostics bag.
    create_table :chorus_results do |t|
      t.references :resultable, polymorphic: true, null: false   # WorkOrder or Plan (Task in Phase 2)
      t.json     :argv,     default: []   # the argv this invocation ran
      t.string   :cwd                     # the working directory it ran in
      t.boolean  :success                 # recorded outcome of this one run
      t.string   :external_session_id     # the runtime session id (latched from the stream)
      t.decimal  :cost_usd, precision: 12, scale: 6   # what the run cost
      t.integer  :duration_ms             # wall-clock duration
      t.integer  :num_turns               # turns taken
      t.json     :usage                   # token-usage bag
      t.json     :tool_calls              # tool-call diagnostics bag
      t.boolean  :interrupted             # did the run get interrupted mid-stream
      t.boolean  :is_error                # did the runtime report an error
      t.json     :messages, default: {}   # plain json diagnostics bag
      t.timestamps
    end
  end
end
