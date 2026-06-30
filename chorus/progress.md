
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



