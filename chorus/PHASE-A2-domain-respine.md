# PHASE A2 — Chorus domain respine

## Why this plan exists

Phase A shipped green with this spine:

```
Organization → Workspace → Project → Issue
Organization → Role, Organization → Agent, Issue → Agent (optional)
```

In that model the Organization reached Projects *through* Workspace
(`has_many :projects, through: :workspaces`), Project carried a required
`workspace_id` and no Organization link of its own, and Workspace was doing
double duty as both a structural node in the ownership hierarchy and the place
work happens.

That double duty was the flaw. Workspace is an **execution surface**, not a node
in the ownership chain. This plan re-spines the domain so ownership flows through
an explicit intent chain and Workspace becomes a durable, serial execution
context.

**Target spine:**

```
Organization → Strategy → Goal → Project → Issue        (ownership / intent)
Workspace (durable, serial) ── hosts one active Project, has_many Artifacts
Organization → Role, Organization → Agent               (participants)
Issue → Agent (optional; the claim)                     (agent meets workspace here)
```

Net model count goes from six to nine: **Strategy**, **Goal**, and **Artifact**
are new; **Workspace** changes role; **Project** and **Organization** re-wire.

## Operating rules for this refactor

These come from `../CLAUDE.md` and matter especially here because we are
reshaping already-green code:

- **Edit migrations in place.** Chorus is pre-v1 with no consumers. Do not add
  corrective migrations. Open the original `create_chorus_*` migrations and
  change them, add new `create_*` migrations only for the genuinely new tables
  (strategies, goals, artifacts), and renumber/order them so the dependency
  order is correct (a table's `belongs_to` target must be created before it).
- **Move models, factories, and specs together.** When a model's associations
  change, its factory (`spec/factories/chorus_*.rb`) and its specs change in the
  same step.
- **Document current state only.** Update `README.md` to describe the new spine
  as if it were always so. No "previously Workspace owned Project" archaeology.
- **Stay OKF-naive.** Artifact will eventually reference OKF bundles, but in this
  phase Artifact is a generic Chorus table with a string `kind` and a locator.
  Do not import anything from OKF.
- **This phase excludes heartbeat and atomic checkout.** Those are in
  `PHASE-B-heartbeat-and-checkout.md`. Here, Issue → Agent stays a simple optional
  `belongs_to` exactly as today. Do not add claim/lock/lease columns yet.

Run `bin/ci` (or `bin/rails` against `spec/dummy`) green after each step before
moving to the next.

## Migration ordering

Because `belongs_to` targets must exist first, the final create-order is:

1. `chorus_organizations`  (unchanged)
2. `chorus_strategies`     (new) → organization
3. `chorus_goals`          (new) → strategy
4. `chorus_roles`          (unchanged) → organization
5. `chorus_workspaces`     (edited) → organization
6. `chorus_agents`         (unchanged) → organization, role
7. `chorus_projects`       (edited) → goal, (no workspace_id)
8. `chorus_artifacts`      (new) → workspace
9. `chorus_workspaces.active_project_id` — added to the workspaces migration
   AFTER projects exist, OR as the last step within a single migration run.

Note the cycle: Workspace references its active Project, and Project formerly
referenced Workspace. We break the cycle by (a) removing `workspace_id` from
Project entirely, and (b) giving Workspace a **nullable** `active_project_id`.
Since the FK is nullable and added after `chorus_projects` is created, ordering
is clean: create workspaces without the column, create projects, then
`add_reference :chorus_workspaces, :active_project` in the workspaces migration's
tail or in step 9. Pre-v1, fold this into the workspaces `create_*` migration
using a separate `add_reference` after the projects table is defined is not
possible within one migration; instead place the `active_project_id`
`add_reference` in the **projects** migration (step 7), so projects exists first.

## Step-by-step

### Step 1 — New model: Strategy

Migration `create_chorus_strategies` (new), ordered right after organizations:

```ruby
create_table :chorus_strategies do |t|
  t.references :organization, null: false,
    foreign_key: { to_table: :chorus_organizations }
  t.string :name, null: false
  t.text :description
  t.string :status
  t.timestamps
end
```

Model `app/models/chorus/strategy.rb`:

```ruby
module Chorus
  class Strategy < ApplicationRecord
    belongs_to :organization
    has_many :goals, dependent: :destroy
    validates :name, presence: true
  end
end
```

Factory `spec/factories/chorus_strategies.rb` and model spec
`spec/models/chorus/strategy_spec.rb` (validations + associations, mirroring the
existing spec idiom). No slug (slug stays on Organization and Project only).

### Step 2 — New model: Goal

Migration `create_chorus_goals` (new):

```ruby
create_table :chorus_goals do |t|
  t.references :strategy, null: false,
    foreign_key: { to_table: :chorus_strategies }
  t.string :name, null: false
  t.text :description
  t.string :status
  t.timestamps
end
```

Model `app/models/chorus/goal.rb`:

```ruby
module Chorus
  class Goal < ApplicationRecord
    belongs_to :strategy
    has_one :organization, through: :strategy
    has_many :projects, dependent: :destroy
    validates :name, presence: true
  end
end
```

Factory + model spec as above.

### Step 3 — Re-wire Organization

`app/models/chorus/organization.rb`. Remove the through-workspaces project
reach; add the strategy/goal reach.

```ruby
module Chorus
  class Organization < ApplicationRecord
    has_many :strategies, dependent: :destroy
    has_many :goals, through: :strategies
    has_many :roles, dependent: :destroy
    has_many :agents, dependent: :destroy
    has_many :workspaces, dependent: :destroy
    has_many :projects, through: :goals

    validates :name, presence: true
    validates :slug, uniqueness: true, allow_blank: true
  end
end
```

The organizations migration is unchanged. Update
`spec/models/chorus/organization_spec.rb` to assert the new associations
(`projects` now reached through `goals`, plus `strategies`).

### Step 4 — Re-wire Project (drop workspace_id, add goal_id)

Edit the **original** `create_chorus_projects` migration in place. Replace the
`workspace` reference with a `goal` reference, and add the workspaces
`active_project` back-reference here (so projects exists before the FK is added):

```ruby
class CreateChorusProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :chorus_projects do |t|
      t.references :goal, null: false,
        foreign_key: { to_table: :chorus_goals }
      t.string :name, null: false
      t.string :slug
      t.text :description
      t.string :status
      t.timestamps
    end

    # Workspace's active-project slot — added here, after projects exists,
    # to break the workspace<->project cycle. Nullable on purpose.
    add_reference :chorus_workspaces, :active_project, null: true,
      foreign_key: { to_table: :chorus_projects }
  end
end
```

Model `app/models/chorus/project.rb`:

```ruby
module Chorus
  class Project < ApplicationRecord
    belongs_to :goal
    has_one :strategy, through: :goal
    has_one :organization, through: :goal

    # A project is hosted by at most one workspace at a time (the workspace
    # whose active_project_id points at it). Inverse of Workspace#active_project.
    has_one :hosting_workspace, class_name: "Chorus::Workspace",
      foreign_key: :active_project_id, inverse_of: :active_project,
      dependent: :nullify

    has_many :issues, dependent: :destroy

    validates :name, presence: true
  end
end
```

Update `spec/factories/chorus_projects.rb` (association `goal` instead of
`workspace`) and `spec/models/chorus/project_spec.rb`.

### Step 5 — Re-role Workspace (durable, serial host of one project)

Edit the **original** `create_chorus_workspaces` migration in place. It keeps
`organization`, gains nothing in its own `create_table` (the `active_project_id`
column is added by the projects migration in Step 4 to satisfy ordering). Leave
the create_table as:

```ruby
create_table :chorus_workspaces do |t|
  t.references :organization, null: false,
    foreign_key: { to_table: :chorus_organizations }
  t.string :name, null: false
  t.text :description
  t.timestamps
end
```

Model `app/models/chorus/workspace.rb`:

```ruby
module Chorus
  class Workspace < ApplicationRecord
    belongs_to :organization
    belongs_to :active_project, class_name: "Chorus::Project",
      optional: true, inverse_of: :hosting_workspace

    has_many :artifacts, dependent: :destroy

    validates :name, presence: true
  end
end
```

Note: Workspace no longer `has_many :projects` directly. The old
`Workspace has_many :projects` and `Project belongs_to :workspace` are both gone.
A workspace's relationship to projects is now exactly one *active* project at a
time via `active_project_id`.

Project history (which projects have used this workspace over time) is **not**
modelled by a live FK on Project (that was the clobber-prone design). It is
deferred: when history is needed it will be a dedicated join/event table. For
this phase, a Workspace knows only its current active project. This is the
"err toward simplicity / defer speculative capability" rule — history is a
hypothetical until a concrete need appears.

Update `spec/factories/chorus_workspaces.rb` and
`spec/models/chorus/workspace_spec.rb` accordingly.

### Step 6 — New model: Artifact

Migration `create_chorus_artifacts` (new), ordered after workspaces:

```ruby
create_table :chorus_artifacts do |t|
  t.references :workspace, null: false,
    foreign_key: { to_table: :chorus_workspaces }
  t.string :name, null: false
  t.string :kind          # e.g. "git_repo", "okf_bundle" — open vocabulary
  t.string :locator       # URL / path / identifier; type-agnostic
  t.text :description
  t.timestamps
end
```

Model `app/models/chorus/artifact.rb`:

```ruby
module Chorus
  class Artifact < ApplicationRecord
    belongs_to :workspace
    validates :name, presence: true
  end
end
```

`kind` is a plain string by convention; Chorus blesses no artifact type. Factory
+ model spec as above.

### Step 7 — Agent and Role (mostly unchanged; confirm no workspace FK)

`chorus_agents` and `chorus_roles` migrations and models are unchanged. The key
invariant to assert in specs: **Agent has no `workspace_id`**. An Agent reaches a
Workspace only through a claimed Issue → Project → hosting Workspace. Add (or
keep) `Agent has_many :issues, dependent: :nullify` and the optional
`belongs_to :role` exactly as today.

Issue is unchanged in this phase:

```ruby
module Chorus
  class Issue < ApplicationRecord
    belongs_to :project
    belongs_to :agent, optional: true
    validates :title, presence: true
  end
end
```

### Step 8 — Controllers, routes, views, i18n

The shipped engine has full MVC for organizations, roles, agents, projects,
issues, workspaces. Respine the presentation layer to match:

- **Add** controllers/views/routes for `strategies`, `goals`, `artifacts`
  following the existing scaffolded idiom (index/show/new/edit/_form/_partial).
- **Projects**: the new/edit form now selects a **Goal** (not a Workspace).
  Update `_form.html.erb` and the controller's strong params (`goal_id` replaces
  `workspace_id`).
- **Workspaces**: show the active project and the list of artifacts; the form
  may set `active_project_id` (nullable). Remove any "new project under
  workspace" affordance.
- **Routes** (`config/routes.rb`): nest sensibly — `strategies` under the org,
  `goals` under strategy, `projects` under goal, `artifacts` under workspace —
  or keep flat resources matching the current style. Match whatever the existing
  routes.rb already does; do not restyle the routing approach.
- **i18n**: add `chorus.*` keys for the three new models in
  `config/locales/en.yml`, and the matching `es.yml` keys in
  `spec/dummy/config/locales/es.yml`. All new strings via `t()`. No literal
  Tailwind colours in any new view — semantic tokens only (see `app/assets/
  stylesheets/chorus/tokens.css`).

### Step 9 — Request specs and i18n spec

- Add request specs for `strategies`, `goals`, `artifacts` under
  `spec/requests/chorus/`, mirroring the existing ones.
- Update `organizations`, `projects`, `workspaces` request specs for the new
  associations and form fields.
- Update `spec/requests/chorus/i18n_spec.rb` to cover the new models' strings.
- Update `lib/chorus/seeds.rb` and `spec/dummy/db/seeds.rb` to build a coherent
  graph along the new spine (org → strategy → goal → project → issue, plus a
  workspace with an active project and a couple of artifacts).

## Done when

- `bin/ci` is green.
- No `workspace_id` exists on `chorus_projects`; no `project`/`projects`
  association couples Workspace to Project except `active_project`.
- No `workspace_id` on `chorus_agents`.
- Organization reaches projects through `goals`; Project reaches Organization
  through `goal → strategy`.
- Strategy, Goal, Artifact have models, factories, specs, MVC, and i18n.
- `README.md` describes the new spine in present tense only.
- `db/migrate` contains in-place-edited originals plus new tables in correct
  dependency order; no corrective migrations.

## Explicitly deferred (do not build now)

- Workspace → project **history** (only the active project is modelled).
- Heartbeat scheduling and atomic Issue checkout/claim/lock/budget — see
  `PHASE-B-heartbeat-and-checkout.md`. (Workspace project history is parked in
  that same document.)
- Any OKF integration on Artifact (Artifact stays a generic Chorus row).
- Multiple active projects per workspace (serial-by-design; not a limitation to
  remove).
