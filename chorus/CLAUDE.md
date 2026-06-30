# CLAUDE.md — chorus engine

Guidance for Claude Code working **inside the Chorus gem**.

Read the shared monorepo context in `../CLAUDE.md` first. It carries the
cross-project lifecycle rules (pre-v1.0: edit migrations in place, document
current state only, err toward simplicity), shared conventions (semantic colour
tokens, i18n discipline, string `status`/`kind`, `chorus_*` table prefix), and
the stack. This file carries only what is specific to Chorus.

## What Chorus is

A mountable Rails engine (`isolate_namespace Chorus`) that models human/AI
participant coordination as a real-world org chart: an organisation has a
strategy, derives goals from it, goals inspire projects, projects carry issues,
and the work happens in workspaces where projects and issues meet agents and
artifacts. Chorus is a non-opinionated coordination framework — it limits its
opinions so as not to rule out legitimate setups (e.g. a single project needing
both a Rails repo and a Solana repo).

## The boundary that defines Chorus

**Chorus is OKF-naive.** This is the single most important invariant. Chorus
owns its entire database schema with real foreign keys between `chorus_*`
tables. OKF is a document store added later as a *consumer* relationship, never
a structural dependency. Do not introduce any OKF table, model, concept, or
invariant into Chorus. When working in Chorus, OKF does not exist. (Artifacts —
see below — will eventually *reference* OKF bundles, but Chorus models the
reference generically and knows nothing about OKF's internals.)

### Corollary: no content columns on domain tables

Domain models that carry narrative content (Strategy, Goal, Project, Issue) do
**not** get a `body`/`content`/`markdown` column. Content lives behind a
Chorus-owned content *seam* (interface + naive default backend), with real
backends — directory, ActiveStorage, OKF — supplied by an optional
`chorus-storage` adapter gem the host installs. A `body` column would become a
competing source of truth and force a two-master sync the moment a document store
is added; the seam avoids that and keeps Chorus grep-clean of OKF. The seam
itself is built only when the first content feature needs it; until then the
binding rule is simply: **add no content columns.** Full rationale and the
build sequence are in `ARCHITECTURE-content-storage.md`.

## Domain spine (the ERD)

The intent spine runs strategy → execution. Ownership flows down this chain;
this is how a Project reaches its Organization.

```
Organization
  has_many :strategies              (one active early; table supports many)
Strategy        belongs_to :organization
  has_many :goals
Goal            belongs_to :strategy
  has_many :projects
Project         belongs_to :goal
  has_many :issues
Issue           belongs_to :project
```

Execution surface, separate from the intent spine:

```
Workspace       belongs_to :organization
  durable; hosts ONE active project at a time (serial)
  has_many :artifacts
  belongs_to :active_project (Chorus::Project, optional) — the active slot
  active project tracked by nullable active_project_id
  (project HISTORY beyond the current active project is deferred — see PHASE-B)
Artifact        belongs_to :workspace
  first-class; string `kind` (e.g. "git_repo", "okf_bundle"); a locator
  Chorus blesses no artifact type — new kinds are added by convention
Project         optionally currently-in a Workspace (the active slot)
```

Participants:

```
Role            belongs_to :organization
Agent           belongs_to :organization; belongs_to :role (optional)
```

## Load-bearing invariants

- **Project reaches Organization through Goal → Strategy, not through
  Workspace.** Workspace is an execution context, not a node in the ownership
  hierarchy. Do not give Workspace a structural claim on the Org→Project chain.
- **Workspace is durable and serial.** It outlives any single project and hosts
  one active project at a time via the nullable `active_project_id`. This is
  deliberate: serial reuse prevents concurrent projects from clobbering each
  other's artifacts. Do not model Workspace↔Project as a live many-to-many.
  Past-occupant *history* is deliberately not modelled yet (only the current
  active project is) — it is parked in PHASE-B.
- **Artifact is first-class and type-open.** A workspace holds many artifacts
  (multiple repos, OKF bundles) of different `kind`s. Chorus must never special-
  case a particular stack (Rails, Solana, etc.); that is what keeps Chorus
  unopinionated.
- **Agent attachment is mediated by the Issue claim.** An Agent does *not* carry
  a `workspace_id`. An Agent meets a Workspace only by claiming an Issue, whose
  Project occupies that Workspace's active slot. Keep agent↔workspace out of the
  schema as a direct FK.
- **Strategy → Goal is one-to-many; keep the intent spine a tree.** A Goal
  belongs to exactly one Strategy.
- **`status`/`kind` are strings; `slug` only where it earns its place** (carried
  on Organization and Project per the established convention).

## Layout

- `app/models/chorus/` — `organization`, `strategy`, `goal`, `project`,
  `issue`, `workspace`, `artifact`, `agent`, `role`.
- `app/controllers/chorus/`, `app/views/chorus/` — namespaced MVC.
- `db/migrate/` — edited in place pre-v1 (see `../CLAUDE.md`).
- `config/locales/en.yml` — `chorus.*` namespace. `es.yml` lives in
  `spec/dummy/config/locales/`.
- `spec/` — RSpec + FactoryBot; model specs under `spec/models/chorus/`,
  request specs under `spec/requests/chorus/`.

## Status

The nine-model spine above is live (Organization, Strategy, Goal, Role, Agent,
Workspace, Project, Artifact, Issue): ownership flows Organization → Strategy →
Goal → Project → Issue, and Workspace is a durable, serial execution surface that
hosts one active project and holds artifacts. Each model has a model, factory,
specs, full MVC, and i18n; the suite is green. Heartbeat and atomic
issue-checkout remain deferred to `PHASE-B-heartbeat-and-checkout.md`; project
history beyond a workspace's single active project is also deferred (and is
parked in that same PHASE-B document).

## Tests

Run with `bin/rails` against `spec/dummy`, or `bin/ci`. When a model changes,
move its factory (`spec/factories/chorus_*.rb`) and specs in the same step as
the in-place migration edit, so schema and fixtures stay together.

**Test only what a harness can honestly claim.** Chorus tests that the harness is
internally sound and that a full coordination lifecycle composes end-to-end
against a *synthetic* domain. Chorus never tests *efficacy* ("did this produce
useful work") — efficacy requires a domain, and the domain belongs to downstream
hosts (Factory, lgat-admin), which own the definition of "done". Keep synthetic
test domains deliberately meaningless so specs cannot smuggle domain opinions
into the non-opinionated framework. See `ARCHITECTURE-testing-scope.md`.
