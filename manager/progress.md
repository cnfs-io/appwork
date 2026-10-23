# 004 — Org extraction to micro_manager + MVC teardown

First entry for this gem. `micro_manager` is the standalone, OKF-backed **Org**
domain that was extracted out of Chorus: strategy → goal → project → ticket. It
stands on its own and *optionally* leans on Chorus for agent orchestration when
Chorus is present. Dependency runs `micro_manager → chorus` **only** as string
`class_name:` references — never a Ruby `require`. The name deliberately does not
reference Chorus.

## What shipped

- **Base wiring.** `Appwork::Manager::ApplicationRecord` now
  `include Appwork::Okf::Consumer`; the gemspec gains a `cnfs_okf` dependency. Load
  graph is `micro_manager → okf` (+ partitia-support, via the existing plugin
  registration) only — no chorus in the gemspec, no `require "appwork/chorus"` anywhere.

- **Models** (renamespaced `Appwork::Chorus::` → `Appwork::Manager::`):
  - `Strategy` — `has_many :goals`, `has_many :projects, through: :goals`,
    `has_one_okf :concept`, `has_many_okf :view_ports`.
  - `Goal` — `belongs_to :strategy`, `has_many :projects`, `has_one_okf :concept`.
  - `Project` — `belongs_to :goal`, `has_one :strategy, through: :goal`,
    `has_many :tickets`, and the polymorphic inverse
    `has_one :workspace, class_name: "Appwork::Chorus::Workspace", as: :workable`
    (a STRING class_name — no load-time dep on Chorus).
  - `Ticket` (was Chorus's `Issue`) — `belongs_to :project`,
    `belongs_to :agent, class_name: "Appwork::Chorus::Agent", optional: true`.

- **Migration** `20260620120002_create_micro_manager_schema.rb` —
  `appwork_manager_strategies/goals/projects/tickets`. `tickets.agent_id` carries a
  **real FK to `appwork_chorus_agents`**, enforceable because chorus and micro_manager
  tables are colocated in one database. Internal FKs (goal→strategy,
  project→goal, ticket→project) point at the `micro_manager_*` tables.

- **Specs + factories** moved from Chorus and renamespaced (`issue_spec` →
  `ticket_spec` testing `Appwork::Manager::Ticket`; factories define
  `:appwork_manager_strategy/goal/project/ticket`). `spec/rails_helper.rb` was a
  broken skeleton — fixed to boot `dummy/config/environment`, load FactoryBot
  from `spec/factories`, and include the short syntax. The cross-gem seam is
  exercised end-to-end: a `Appwork::Chorus::Workspace` occupies a `Appwork::Manager::Project`
  through `workable`, and a `Appwork::Manager::Ticket` is assigned a `Appwork::Chorus::Agent`.
  **30 examples, 0 failures.**

## Decisions worth flagging

1. **Chorus stays in the dummy Gemfile, not the gemspec.** The dummy needs the
   `Appwork::Chorus::Workspace`/`Appwork::Chorus::Agent` constants and the `appwork_chorus_agents` table at
   runtime, so `gem "chorus"` remains in the dummy's Gemfile (app-assembly). The
   **gemspec** declares no chorus dependency — the load-graph invariant is about
   the gem's own code, which only ever names Chorus via string `class_name:`.

2. **Migrations aggregate through Partitia::Support.** The dummy's `database.yml`
   points `development` at `Partitia::Support.migrations_paths[:primary]`, which unions
   every registered plugin's `db/migrate`. So `db:migrate` here runs okf →
   chorus → micro_manager → partitia-ui in version order, giving the dummy the
   `appwork_chorus_agents` table before the tickets FK is applied.

## How to run it

    cd gems/micro_manager
    bin/rails db:create db:migrate           # okf → chorus → micro_manager → partitia-ui
    RAILS_ENV=test bin/rails db:test:prepare
    bundle exec rspec        # 30 examples, 0 failures

Schema note: the schema is edited/created under versions that don't line up with
this gem's own single migration, so the test DB needs
`RAILS_ENV=test bin/rails db:test:prepare` once after a fresh `db:migrate` (the
`maintain_test_schema!` auto-loader is unreliable on the first bootstrap). No
commit made.

# 005 — Workable adoption

Executed and green. Builds on 004: Project and Ticket become **Chorus workables**.
**37 examples, 0 failures** (was 30; +7 adoption specs).

## What shipped

- **`Appwork::Manager::Project`** and **`Appwork::Manager::Ticket`** each gain
  `has_one_okf :concept` and `include Appwork::Chorus::Workable`. They are now occupiable
  by a `Appwork::Chorus::Workspace` (polymorphic `workable`) and carry an opaque `status`
  over their concept's custom_frontmatter.
- **Project's hand-written `has_one :workspace` (added in 004) removed** — the
  concern now supplies that inverse, so declaring it again would double-declare.
  Ticket gains the inverse fresh via the concern.
- **Gemspec now declares `chorus`** (`spec.add_dependency "chorus"`). The
  dependency is real and honest (models include a Chorus concept); the dummy
  Gemfile's `path:` line still resolves it locally. Hosts → Chorus is the
  allowed direction.
- **Specs:** adoption blocks on `project_spec`/`ticket_spec` (is-a-workable,
  carries a concept, occupied-by-workspace, opaque status round-trips through the
  concept). New `spec/support/workable_concept_helper.rb` builds a file-backed
  OKF concept and claims it onto a record; `rails_helper` now loads `spec/support`.

## Decisions worth flagging

1. **The legacy `status` column on `appwork_manager_projects`/`_tickets` is now
   orphaned.** `Appwork::Chorus::Workable#status=` shadows the AR column writer, so the
   column is unreachable through the model and no longer driven. The Project and
   Ticket factories dropped their `status "active"` line (it was routing into the
   concern accessor against a nil concept and raising). The column's fate is the
   status/event-sourcing ADR's call — 005 deliberately does not wire to it or
   drop it. (Strategy/Goal keep their `status` column + factory value: they do
   NOT include Workable, so their `status=` is still the plain column writer.)
2. **Project gained a concept.** Per the plan's check: Project did not previously
   `has_one_okf :concept` (only Strategy/Goal did). A workable needs one, so
   Project (like Ticket) now carries a Concept — the desired shape for an
   occupiable spine node.

## How to run it

    cd gems/micro_manager
    bin/rails db:create db:migrate
    RAILS_ENV=test bin/rails db:test:prepare
    bundle exec rspec        # 37 examples, 0 failures

# 006 — Every spine node is a Workable; status via okf_frontmatter

Executed and green. Adopts Chorus 006 across the whole spine. **51 examples, 0
failures** (was 37; +14 status/occupiability examples across the four models).

## What shipped

- **All four spine models — Strategy, Goal, Project, Ticket — now:**
  `has_one_okf :concept` → `okf_frontmatter :status` → `include Appwork::Chorus::Workable`
  (in that order). Strategy and Goal are newly occupiable (gained
  `include Appwork::Chorus::Workable`); Project and Ticket gained `okf_frontmatter :status`
  (their status previously came from the now-slimmed Workable concern).
- **Status is uniform and concept-backed** on all four: `okf_frontmatter :status`
  reads/writes the OKF concept's custom_frontmatter, round-trips to disk via the
  existing persist path, stays opaque (no vocabulary, no events).
- **`status` column dropped from all four `micro_manager_*` spine tables.**
  Projects/tickets were already clean (005 follow-up); strategies/goals dropped
  here. A column would be shadowed by the `okf_frontmatter :status` accessor.
- **Factories:** strategies/goals dropped their `status "active"` line (as
  projects/tickets did in 005) — the accessor now targets the concept, and there
  is no column.
- **Specs:** each of the four models asserts is-a-workable, no `status` column,
  occupied-by-`Appwork::Chorus::Workspace`, and status read-nil / write+merge / persist.

## Decisions worth flagging

1. **Occupiability and status are independent mechanisms.** `Appwork::Chorus::Workable`
   gives the workspace inverse; `okf_frontmatter :status` (an OKF-consumer
   facility) gives the status accessor. A model could be one without the other;
   all four spine models happen to be both.
2. **Strategy/Goal are now occupiable** on the premise that decomposition is work
   done in a Workspace (deriving goals occupies a Strategy as executing occupies a
   Ticket). Differentiated occupation behavior (Decomposable vs. Terminal) is a
   later plan — 006 only makes them uniformly occupiable.

## How to run it

    cd gems/micro_manager
    bin/rails db:create db:migrate
    RAILS_ENV=test bin/rails db:test:prepare
    bundle exec rspec        # 51 examples, 0 failures
