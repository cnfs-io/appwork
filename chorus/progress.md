
# Phase A

What was built

Domain (6 resources, all chorus_-prefixed, all Chorus::-namespaced):
- Migrations with explicit FK to_table: (schema regenerates cleanly), models with exact ERD associations/validations/dependent: (incl. has_many :projects, through: :workspaces and has_one :organization, through: :workspace), routes + root.
- Resourceful controllers + clean scaffold views (index/show/new/edit/_form/row partial) — Tailwind semantic tokens only, Turbo (list in a turbo-frame, turbo_stream.remove on destroy), every string via t() / Rails model+attribute i18n.
- Factories, 84 specs green (model: validations/associations/dependent/through; request: CRUD per resource; i18n: en default + ?locale=es).
- Idempotent seeds via Chorus::Seeds.seed! (rake chorus:seed + dummy db/seeds.rb) — Acme Chorus org, all console traversals verified.

Theming proven: dummy's Tailwind entry imports the engine's @theme tokens (neutral defaults) and overrides :root to teal/slate — compiled CSS confirms the host override wins, no Chorus view touched. i18n proven: server renders Spanish under ?locale=es; engine ships only en.yml.

DoD all green: zero OKF refs, zero literal Tailwind colors, rubocop clean, dummy boots and serves at /chorus.

Three decisions worth flagging

1. Locale handling lives in Chorus::ApplicationController, not the dummy's. Under isolate_namespace, engine controllers don't inherit the host's ApplicationController, so the plan's "wire it in the dummy" wouldn't reach engine pages. It's still neutral — it honors whatever locales the host configured and ships only en.
2. Destroy branches on the Turbo-Frame header. From the list frame → surgical turbo_stream.remove; from the show page (no frame) → redirect_to index, :see_other. Without this, deleting from a show page leaves a stale page.
3. Added the engine migrate path explicitly in spec/dummy/config/application.rb. Rails' :append_migrations skips auto-appending because the dummy is nested inside the engine root.

Explore it

cd spec/dummy
bin/rails db:seed
bin/rails server          # browse /chorus, flip EN/ES in the header
bin/rails console         # Chorus::Issue.first.project.organization

The generator scripts live in /tmp (not committed); all engine files are written directly. Nothing is committed — let me know if you want a commit/branch.

✻ Sautéed for 20m 47s

※ recap: Phase A of the Chorus Rails engine is fully implemented with all 84 specs green, theming and Spanish locale proven, and seeds working. Next action is to commit the work if you want it saved. (disable recaps in /config)

# Phase A2

PHASE-A2-domain-respine.md is executed and green. Summary of what shipped:

Spine re-architected from six models (Org→Workspace→Project→Issue) to nine along the intent spine:
Organization → Strategy → Goal → Project → Issue, with Workspace (durable, serial) hosting one active_project and owning Artifacts.

Migrations (edited in place, renumbered for dependency order — no corrective migrations):
- New: chorus_strategies, chorus_goals, chorus_artifacts.
- chorus_projects: dropped workspace_id, added goal_id, and adds the nullable chorus_workspaces.active_project_id back-reference after projects exists (breaking the cycle).
- Roles/workspaces/agents/issues renumbered only.

Models / factories / specs: Strategy, Goal, Artifact added; Organization (has_many :projects, through: :goals), Project (belongs_to :goal, has_one :organization through: :goal, has_one :hosting_workspace), Workspace (belongs_to :active_project optional, has_many :artifacts) rewired. Model + request specs updated, including the agent-has-no-workspace_id and active-slot invariants.

MVC + i18n: full CRUD controllers/views/routes for the three new resources following the existing scaffold idiom; projects form selects a Goal; workspaces form sets the active project and the show page lists artifacts; nav, en.yml, and dummy es.yml updated. Semantic color tokens only.

Seeds/docs: lib/chorus/seeds.rb and dummy seeds rebuilt along the new spine; README and engine CLAUDE.md rewritten in present tense.

Status: 135 examples, 0 failures; RuboCop clean; db:migrate + db:seed work via rake.

One fix worth flagging: I removed the config.paths["db/migrate"] << Chorus::Engine.root... line that Phase A added to spec/dummy/config/application.rb. The engine already auto-contributes its migrations to the dummy, so that line duplicated the path and made every rake DB task abort with DuplicateMigrationNameError: CreateChorusOrganizations. Removing it makes db:migrate/db:seed work and keeps specs green (rspec uses schema.rb, unaffected). Note: after any change to schema.rb (including the rubocop bracket-spacing autocorrect), the test DB needs RAILS_ENV=test bin/rails db:test:prepare once before specs — same behavior Phase A had.




# Phase A2b — External accounts + GitHub repo provisioning

PHASE-A2b-external-accounts.md executed. What shipped:

**Schema (edited in place).** Added `chorus_external_accounts` to the consolidated
`20260620120001_create_chorus_schema.rb` — STI `type`, `name`, serialized
`settings` bag, unique `[type, name]` index — modeled on the `chorus_sources`
block. Dummy `spec/dummy/db/schema.rb` updated to match; ran
`RAILS_ENV=test bin/rails db:test:prepare`.

**Config.** `Chorus::Credentials` (`lib/chorus/credentials.rb`) — a
`CnfsSupport::Config` subclass (anyway_config): `config_name :chorus_credentials`,
`env_prefix :chorus`, `attr_config :github_token`. Resolves the token from
`credentials.chorus_credentials.github_token` → `ENV["CHORUS_GITHUB_TOKEN"]`;
never a source literal, never serialized, never in a payload. Required from
`lib/chorus.rb`, mirroring how `CnfsCognito` pulls in its `Config`.

**Models.** `Chorus::ExternalAccount` STI base — `setting` macro and the pinned
`instrument` helper copied verbatim from `Source`; no provisioning interface on
the base (provisioning isn't universal across kinds). Subclasses: `GitHub`
(keyless — `name` is the org login; `#create_repository` POSTs via stdlib
`Net::HTTP` and returns the repo `ssh_url`), plus data-only `Gitlab`, `Aws`,
`GoogleCloud` (targeting config in the bag only — no SDK-credential columns).

**Zeitwerk.** `github.rb` autoloads to `ExternalAccount::GitHub`; registered a
`GitHub` acronym via a `chorus.inflections` initializer in `engine.rb` so it
resolves to the capitalized constant rather than `Github`.

**Specs.** `spec/models/chorus/external_account_spec.rb` (16 examples): STI base,
settings bag, STI resolution, `create_repository` happy/failure paths,
instrumentation, and secret hygiene — network stubbed at the `Net::HTTP`
boundary, coordination-only. The secret-hygiene assertion was validated as
load-bearing by mutation (leaking the token into the payload turned both hygiene
tests red, in success and failure paths) before being trusted.

**Instrumentation prefix.** `CnfsSupport.component_tag` was refactored (in
`gems/support`, uncommitted at the time) to prepend `cnfs_`, so events now emit
under `cnfs_chorus.*`. Updated the instrumentation specs to match:
`external_account_spec.rb` asserts `cnfs_chorus.external_account.create_repository`
(and that the pinned subject never leaks `git_hub`), and `source_spec.rb`'s five
instrumentation examples were moved from `chorus.source.*` to `cnfs_chorus.source.*`.

**i18n.** `activerecord.models.chorus/external_account` + attribute labels
(`name`, `group`, `account_id`, `region`, `default_role_arn`, `project_id`,
`service_account_email`) added to `en.yml`. STI subclasses not enumerated
(matching the `Source` precedent).

**Pending next slice.** Onboarding CRUD — the MVC surface for a tenant to add
GitHub org(s) and the other account kinds — is deliberately out of this slice and
is the next follow-up.

Green counts: source + external_account model specs 39, 0 failures; RuboCop clean.
Note: 10 pre-existing failures remain in the suite (`Chorus::Agent#kind=`, from a
separate in-flight Agent refactor — the agent factory sets `kind` but the
table/model no longer carries it). Untouched here; not caused by this slice.
No commit made.

# 004 — Skill catalog, curation, taxonomy, and the npx wrapper (plumbing only)

`doc/plans/004-skill-catalog-and-npx.md` executed. Plumbing only — no policy, no
relevance matching, no workspace materialization (all parked as `# 004 deferred:`
seam comments in the models/service).

**Schema (edited in place).** Four tables added to the consolidated
`20260620120001_create_chorus_schema.rb`:
- `chorus_catalog_skills` — the upstream mirror. `resource` (owner/repo, null:false),
  nullable `skill_name`, `description`, `install_count`, `repo_topics` (json —
  raw folksonomy, NOT taxonomy), `synced_at`. Unique `[resource, skill_name]`.
- `chorus_curations` — chorus.org's verdict. `resource`, nullable `skill_name`,
  `reputation`. Unique `[resource, skill_name]`.
- `chorus_taxonomies` — the standalone category dimension. `name`, `slug`
  (unique), self-ref `parent_id` (FK to itself). 
- `chorus_skill_categorizations` — bare CatalogSkill↔Taxonomy join, two FKs,
  unique `[catalog_skill_id, taxonomy_id]`. No provenance column (deferred).

**Models.** `Chorus::CatalogSkill`, `Chorus::Curation` (includes
`CnfsSupport::YamlSerializable`), `Chorus::Taxonomy`, `Chorus::SkillCategorization`.
Natural-key joins (`#curation` / `#catalog_skill`) are `find_by` on
`[resource, skill_name]`, NOT FKs — the two sources refresh on different cadences,
so either side may exist alone. Three-state reputation is enforced by row presence
+ a `reputation` inclusion (0..100) that rejects nil on a present row, so
nil (unknown/absent) and 0 (known-bad) can never collide.

**Config.** `Chorus::Config` (`lib/chorus/config.rb`) — a *non-secret*
`CnfsSupport::Config` subclass (`config_name :chorus`), distinct from the
secrets-only `Chorus::Credentials`. `attr_config curation_enabled: true,
reputation_threshold: 50` with `coerce_types` (boolean/integer). No policy
consumes them yet.

**npx wrapper.** `Chorus::SkillCatalog` — a PORO under `app/models/chorus/`
(location choice, see flag 2). Two private shell seams `run_npx` / `capture_npx`
copied from `Source::Git` (array-form `IO.popen`, raise-with-captured-output,
`chdir:` for path/project scope), thin verb wrappers (`search`, `list_repo_skills`,
`add`, `update`, `remove`, `init`), best-effort private parsers (ANSI-stripped),
and `ingest` which upserts `CatalogSkill` on the natural key + stamps `synced_at`.
`-g` is emitted ONLY on `global: true`. Instrumentation pinned to
`cnfs_chorus.skill_catalog.*`.

**Specs (structural only, no network).** 66 new examples, all green (suite: 210
examples, 0 failures, 8 pre-existing pending). Shell seams are stubbed; parsers
are fed committed fixtures captured from real `npx skills` runs
(`spec/fixtures/skills/{find_react,add_list_vercel}.txt`). Covers validations,
natural-key indexes, associations, three-state reputation, argv construction
(esp. `-g` gating and `-a` repetition), parser output, `ingest`
upsert/idempotency, and the YamlSerializable round-trip. RuboCop clean.

Three things flagged (per the plan's ask):

1. **YamlSerializable upserts on the PRIMARY KEY, not the natural key.** The
   round-trip spec passes because we dump *our own* rows (ids included) →
   `delete_all` → reload upserts on those same ids. But a chorus.org whitelist
   distributed WITHOUT ids (just resource/skill_name/reputation) would insert
   fresh ids on every load and then collide with the unique `[resource,
   skill_name]` index on the second load. The concern needs a `unique_by:` option
   (or a natural-key mode) before it can ingest externally-authored YAML. Not
   worked around here — flagged as the plan requested.

2. **Service-object location.** No prior non-AR service precedent existed in the
   gem, so `Chorus::SkillCatalog` is a plain PORO under `app/models/chorus/`
   (the plan's stated fallback). It is not an `ApplicationRecord`, so it does not
   get the railtie-injected `instrument`; it defines its own pinned `#instrument`
   helper (same shape as `Source`).

3. **Config defaults.** `curation_enabled: true` (curated by default),
   `reputation_threshold: 50` (reject the bottom half of graded skills; admit
   nothing chorus.org flagged 0/trash). Chosen as sane plumbing defaults — the
   actual gating policy that reads them is deferred.

4. **CnfsSupport::YamlSerializable wasn't on any autoload path.** It ships in
   `gems/support/app/models/concerns/` but cnfs_support is a *railtie*, not an
   Engine, so its `app/` paths never reach the host's autoload roots, and nothing
   in `lib/cnfs_support.rb` requires it — Chorus::Curation is its first consumer.
   Worked around locally with a `chorus.cnfs_support_concerns` initializer in
   `engine.rb` that adds just that one concerns dir as an autoload root. The
   cleaner home is a central `require` inside cnfs_support once a second consumer
   appears; left as-is to avoid a cross-gem change in a chorus-scoped plan.

How to run it:

    bundle exec rspec spec/models/chorus/{catalog_skill,curation,taxonomy,skill_categorization,config,skill_catalog}_spec.rb

Schema note: because the migration is edited in place (same version as
`schema.rb`), `db:migrate` reloads the same-version schema instead of running the
edits. To regenerate: move `spec/dummy/db/schema.rb` aside, drop/create/migrate
from zero, then `RAILS_ENV=test bin/rails db:test:prepare`. No commit made.

# 004 — Org extraction to micro_manager + MVC teardown

Executed and green. Chorus ends this plan **org-naive and Role-naive**; the org
domain now lives in the sibling `micro_manager` engine (models only, no UI).

## What shipped

**micro_manager (new tenant of the org domain):**
- `MicroManager::ApplicationRecord` now `include CnfsOkf::Consumer`; gemspec
  gains a `cnfs_okf` dependency. Load graph is `micro_manager → okf` (+
  cnfs_support) only — it never `require`s chorus.
- Models: `Strategy`, `Goal`, `Project`, `Ticket` (was `Issue`), renamespaced
  `Chorus::` → `MicroManager::`. Strategy/Goal keep `has_one_okf :concept`;
  Strategy keeps `has_many_okf :view_ports`. `Project#workspace` is the
  polymorphic inverse `has_one … as: :workable, class_name: "Chorus::Workspace"`
  (a STRING — no Ruby dep on Chorus). `Ticket#agent` is
  `belongs_to class_name: "Chorus::Agent", optional: true`.
- Migration `20260620120002_create_micro_manager_schema.rb`: strategies/goals/
  projects/tickets. `tickets.agent_id` carries a **real FK to `chorus_agents`**
  (enforceable because the tables are colocated in one DB). Internal FKs point at
  the `micro_manager_*` tables.
- Specs + factories moved over and renamespaced; `spec/rails_helper.rb` fixed to
  boot `dummy/config/environment`, load FactoryBot from `spec/factories`, and
  include the short syntax. **30 examples, 0 failures.** The cross-gem seam is
  exercised for real: a `Chorus::Workspace` occupies a `MicroManager::Project`
  via `workable`, and a `MicroManager::Ticket` is assigned a `Chorus::Agent`.

**chorus (org- and Role-naive):**
- Deleted models: `Strategy`, `Goal`, `Project`, `Issue`, `Role`.
- `Chorus::Agent` is role-blind and ticket-blind (dropped `belongs_to :role` and
  `has_many :issues`). `Chorus::Workspace` drops `active_project` for
  `belongs_to :workable, polymorphic: true, optional: true` (bare seam; the
  Workable concern + status are plan 005).
- Migration `20260620120001` edited in place: org + role tables removed;
  `chorus_workspaces` gains a polymorphic `workable` reference; the
  `chorus_agents` block loses the role FK and its pre-existing typo is fixed
  (`t.references :agent … agent_profiles` → `t.references :agent_profile …
  chorus_agent_profiles`). Modelling `belongs_to :agent_profile` stays plan 001.
- All scaffold controllers/views + the whole `spec/requests/chorus/` tree retired
  to `.trash` (see below). `config/routes.rb` is now an empty draw block. Dead
  locale keys (strategy/goal/role/project/issue, `active_project`, agent `role`)
  stripped from `en.yml` and the dummy `es.yml`.
- **122 examples, 0 failures** (was 210; the drop is the retired request/i18n
  specs and the org model specs that moved to micro_manager).

## Invariants (all empty / satisfied)
- `grep -rn "micro_manager\\|MicroManager" gems/chorus` → nothing in code
  (plan doc retired to `.trash`).
- No `Chorus::*` model associates to Strategy/Goal/Project/Issue/Ticket/Role.
- `Chorus::Role` exists nowhere (model/factory/spec/view/controller/route/locale).
- `micro_manager` never `require`s chorus (only string `class_name:`).
- Both suites green; both dummies migrate + seed; RuboCop clean on authored files
  (only the pre-existing generated `spec/dummy` noise remains, as in the baseline).

## How to run it

chorus:

    cd gems/chorus
    # migration edited in place at same version → move schema aside to force a real migrate
    rm -f spec/dummy/db/schema.rb spec/dummy/storage/*.sqlite3*
    bin/rails db:create db:migrate
    RAILS_ENV=test bin/rails db:test:prepare
    bundle exec rspec        # 122 examples, 0 failures

micro_manager:

    cd gems/micro_manager
    bin/rails db:create db:migrate           # runs okf → chorus → micro_manager → cnfs_ui
    RAILS_ENV=test bin/rails db:test:prepare
    bundle exec rspec        # 30 examples, 0 failures

## .trash for Roberto to delete (`~/spikes/chorus/.trash/004-org-extraction-mvc-teardown/`, 66 files)
- `chorus/app/controllers/chorus/` — 8 scaffold controllers (agents, artifacts,
  goals, issues, projects, roles, strategies, workspaces). `application_controller.rb` kept.
- `chorus/app/views/chorus/` — 8 model view dirs (48 erb files). `layouts/` kept.
- `chorus/spec/requests/chorus/` — 9 request specs incl. `i18n_spec.rb`.
- `chorus/doc/plans/004-org-extraction-and-mvc-teardown.md` — this plan, shipped.

# 005 — Chorus::Workable concern + status v1

Executed and green. Builds on 004: the bare polymorphic `workable` seam now has a
contract. **132 examples, 0 failures** (was 122; +10 concern specs).

## What shipped

- **`Chorus::Workable`** (`app/models/concerns/chorus/workable.rb`) — the
  participation contract a host model `include`s to become occupiable. Provides:
  - `has_one :workspace, as: :workable, class_name: "Chorus::Workspace",
    dependent: :nullify` (the polymorphic inverse of `Workspace#workable`).
  - `status` / `status=` over the owned concept's `custom_frontmatter` — read is
    nil-safe (`&.`), write is concept-first (no nil-guard → raises loudly on a
    concept-less includer). Same read/write asymmetry as OKF's `okf_frontmatter`.
  - Requirement (documented + spec-proven): the includer must `has_one_okf :concept`.
- **Dummy workable for isolated testing** — `WorkableDummy`
  (`spec/dummy/app/models/`) + a dummy-only `workable_dummies` table in the new
  `spec/dummy/db/migrate/` (that path is auto-consulted once it exists, so the
  table never touches the engine schema). The chorus dummy `ApplicationRecord`
  now `include CnfsOkf::Consumer` so a dummy model can carry a concept.
- **`spec/models/chorus/workable_spec.rb`** (10 examples) — occupancy round-trip,
  release-on-workspace-destroy, `dependent: :nullify` (destroying the workable
  leaves the durable workspace detached), status read/write/merge, disk
  round-trip via `persist_to_disk`, and the concept-first nil-vs-raise contract.

## Decisions worth flagging

1. **Hand-written accessor, not the `okf_frontmatter` macro.** OKF 006 has landed
   (`CnfsOkf::Consumer.okf_frontmatter` exists), but the concern defines
   `status`/`status=` directly per the plan — a Chorus concern owning its own
   accessor reads cleaner than delegating to a host-class macro. Swapping to
   `okf_frontmatter :status` is a named, deferred follow-up.
2. **Status is opaque.** No vocabulary, no `complete?`, no gating, no events, no
   status column on any Chorus table. v1 is a raw ungoverned accessor;
   interpretation is lifecycle (002) + the status/event-sourcing ADR.
3. **Dependency stance relaxed (per the plan).** A host is a Chorus consumer just
   as it is an OKF consumer — `include Chorus::Workable` is honest and
   gemspec-declared host-side. The absolute invariant is directionality: no host
   constant appears in `gems/chorus` (grep empty).

## How to run it

    cd gems/chorus
    rm -f spec/dummy/db/schema.rb spec/dummy/storage/*.sqlite3*
    bin/rails db:create db:migrate
    RAILS_ENV=test bin/rails db:test:prepare
    bundle exec rspec        # 132 examples, 0 failures

Directionality grep (empty):

    grep -rnE "MicroManager|Gtd|micro_manager" gems/chorus/app gems/chorus/lib

# 006 — Separate status from occupiability (Workable = occupiability only)

Executed and green. Refines 005: `Chorus::Workable` fused occupiability with a
status accessor; 006 splits them. **125 examples, 0 failures** (was 132; the 7
status/concept-first examples left the Workable suite along with status).

## What shipped

- **`Chorus::Workable` is occupiability ONLY.** Removed `status`, `status=`, and
  `STATUS_KEY`; what remains is the polymorphic `has_one :workspace,
  as: :workable, dependent: :nullify`. Status is now a host-side facility
  (`okf_frontmatter :status`), orthogonal to occupiability, so it no longer rides
  on Workable. A workable no longer needs a concept for occupiability.
- **`workable_spec.rb` is occupancy-only** (3 examples: round-trip,
  release-on-workspace-destroy, `dependent: :nullify`). Dropped the status and
  concept-first describe blocks and the tmpdir/bundle/concept machinery — the
  bare `WorkableDummy` needs no concept to prove occupiability.
- The dummy workable keeps `has_one_okf :concept` (harmless realism); a comment
  notes occupiability is concept-independent.

## Why (the realization driving it)

Decomposition is work: an agent deriving goals from a Strategy occupies a
Workspace exactly as executing a Ticket does. So every spine node is occupiable —
not just Project/Ticket. Occupiability and status are independent properties and
now use independent mechanisms (`Chorus::Workable` vs. `okf_frontmatter :status`).
Host adoption of both across all four spine nodes lives in micro_manager 006.

## How to run it

    cd gems/chorus
    rm -f spec/dummy/db/schema.rb spec/dummy/storage/*.sqlite3*
    bin/rails db:create db:migrate
    RAILS_ENV=test bin/rails db:test:prepare
    bundle exec rspec        # 125 examples, 0 failures

ADR 0001 updated: the legacy `micro_manager_*` status column is now dropped from
all four spine tables (was: kept on strategies/goals). Directionality grep over
`gems/chorus/app|lib` remains empty.
