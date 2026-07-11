# CLAUDE.md — chorus engine

Guidance for Claude Code working **inside the Chorus gem**.

Read `../CLAUDE.md` (cnfs_* family conventions) first, and above it the workspace
`../../CLAUDE.md` (map + how-we-work). Those carry the shared lifecycle rules
(pre-v1: edit migrations in place), the cnfs_* conventions (string `status`/`kind`,
i18n discipline, secrets, dependency inversion), the skills, and the stack. This
file carries only what is specific to Chorus.

When writing or updating this gem's `README.md`, follow the **readme-authoring**
skill (`.claude/skills/readme-authoring`) — it gates on the code being in a
consistent, non-in-flux state before a line is written.

## What Chorus is

A mountable Rails engine (`isolate_namespace Chorus`) that models human/AI
participant coordination as a real-world org chart: a strategy derives goals,
goals inspire projects, projects carry issues, and the work happens in
workspaces where projects and issues meet agents and artifacts. Chorus holds
**no `Organization` row of its own** — a Chorus database *is* one organization
(see the organization boundary below). Chorus is a non-opinionated coordination
framework — it limits its opinions so as not to rule out legitimate setups (e.g.
a single project needing both a Rails repo and a Solana repo).

## The boundary that defines Chorus

**Chorus consumes OKF; OKF never knows Chorus.** This one-directional
dependency is the single most important invariant. Chorus owns its entire
database schema with real foreign keys between `chorus_*` tables, and on top of
that it is an OKF *consumer*: `Chorus::ApplicationRecord` includes
`CnfsOkf::Consumer`, so every Chorus record is OKF-consumer-capable by design.
Models opt into actual concept-backing with `has_one_okf` where it earns its
place (today `Skill has_one_okf :concept`). The dependency runs strictly one
way — Chorus may reference OKF constants and macros; **OKF must never reference,
name, or know about Chorus** (grep-enforceable: no `chorus` in `okf/`).

This reverses the engine's earlier "OKF-naive" stance (Chorus once owned no OKF
coupling at all). What survived the reversal is the *directionality*, not the
absence of coupling: the sacred rule is now "Chorus→OKF allowed, OKF→Chorus
forbidden," not "no coupling."

### The organization boundary: a database is an organization

Chorus carries **no `Organization` model, table, or owning FK.** The
organizational boundary is the **database**: under `cnfs_tenanted` there is one
physical database per `Iam::Account`, and that per-account database *is* one
organization. Every `chorus_*` record already lives inside exactly one org by
virtue of which database it is in, so an `Organization` row would only restate
what the connection already guarantees — and would invite cross-org rows in a
single table, which the tenancy model exists to prevent.

The consequence for the schema: **Strategy, Role, Workspace, and Agent are
top-level roots** — none of them `belongs_to :organization`, because there is no
organization row to belong to. `Source` and `ExternalAccount` say the same in
their own comments ("account-scoped by tenancy — one physical DB per Account").
Do not reintroduce an `Organization` model or an org-owning FK; scope is the
database, not a column.

### Corollary: no content columns on domain tables

Domain models that carry narrative content (Strategy, Goal, Project, Issue) do
**not** get a `body`/`content`/`markdown` column. Narrative content lives in OKF
concepts, reached via `has_one_okf`. A `body` column would be a competing source
of truth against the OKF concept — a two-master sync problem — so the binding
rule is simply: **add no content columns.** A model that needs narrative content
declares `has_one_okf` and lets the OKF concept own the text.

## Domain spine (the ERD)

The intent spine runs strategy → execution. `Strategy` is the root of the spine
(there is no `Organization` above it — the database is the organization).
Ownership flows down this chain; this is how a Project reaches its Strategy.

```
Strategy                            (root of the intent spine; no owner FK)
  has_many :goals
  has_many :projects, through: :goals
Goal            belongs_to :strategy
  has_many :projects
Project         belongs_to :goal
  has_one  :strategy, through: :goal
  has_many :issues
Issue           belongs_to :project
```

Execution surface, separate from the intent spine (a top-level root — no owner
FK; scoped by the database):

```
Workspace       durable; hosts ONE active project at a time (serial)
  has_many :artifacts
  belongs_to :active_project (Chorus::Project, optional) — the active slot
  active project tracked by nullable active_project_id
  (project HISTORY beyond the current active project is deferred — see the
  heartbeat-and-checkout plan in `doc/plans`)
Artifact        belongs_to :workspace
  first-class; string `kind` (e.g. "git_repo", "okf_bundle"); a locator
  Chorus blesses no artifact type — new kinds are added by convention
Project         optionally currently-in a Workspace (the active slot), via
  Project#hosting_workspace (inverse of Workspace#active_project)
```

Participants (top-level roots — no owner FK; scoped by the database):

```
Role            has_many :agents (nullify)
Agent           belongs_to :role (optional); has_many :issues (nullify)
                has_one_okf :concept
AgentProfile    describes an agent runtime via an attached OKF Concept
                (Agent↔AgentProfile FK direction is being settled — see plan 001)
```

## Load-bearing invariants

- **Project reaches its Strategy through Goal, not through Workspace.** Strategy
  is the top of the ownership chain (the database is the organization above it);
  Workspace is an execution context, not a node in the ownership hierarchy. Do
  not give Workspace a structural claim on the Strategy→Project chain.
- **Workspace is durable and serial.** It outlives any single project and hosts
  one active project at a time via the nullable `active_project_id`. This is
  deliberate: serial reuse prevents concurrent projects from clobbering each
  other's artifacts. Do not model Workspace↔Project as a live many-to-many.
  Past-occupant *history* is deliberately not modelled yet (only the current
  active project is) — it is parked in the heartbeat-and-checkout plan
  (`doc/plans/003-heartbeat-and-checkout.md`).
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
  on Project per the established convention).

## Layout

- `app/models/chorus/` — the domain spine (`strategy`, `goal`, `project`,
  `issue`, `workspace`, `artifact`, `agent`, `role`), plus `agent_profile` and
  `skill` (both OKF-backed via `has_one_okf :concept`; minimal today). There is
  no `organization` model — the database is the organization.
- `app/models/chorus/source.rb` (+ `source/`) — an STI base (`Source::Git` live)
  whose per-kind config lives in a serialized `settings` bag (the `setting`
  macro), not per-kind columns.
- `app/models/chorus/external_account.rb` (+ `external_account/`) — an STI base
  (`ExternalAccount::GitHub` acts; `Gitlab`/`Aws`/`GoogleCloud` are data-only)
  for a tenant's third-party service accounts; same `settings`-bag pattern.
- `app/controllers/chorus/`, `app/views/chorus/` — namespaced MVC.
- `db/migrate/` — edited in place pre-v1 (see `../CLAUDE.md`).
- `config/locales/en.yml` — `chorus.*` namespace. `es.yml` lives in
  `spec/dummy/config/locales/`.
- `spec/` — RSpec + FactoryBot; model specs under `spec/models/chorus/`,
  request specs under `spec/requests/chorus/`.

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

## #coherence

<!-- level: project -->

The durable design claims this gem stands behind. Each is a decision no passing
spec captures; `docs-patrol` checks these for drift. Severity drives the drift
score — kept honest, `[critical]` is boundary/identity only. A `referent` says
how a later session would know the claim stopped being true.

### boundary

- [critical] Chorus consumes OKF one-directionally: Chorus may reference OKF
  constants and macros (`Chorus::ApplicationRecord` includes `CnfsOkf::Consumer`;
  models opt in with `has_one_okf`), but OKF must never reference, name, or know
  about Chorus.
  referent: `grep -ri chorus` under the `okf` gem returns nothing; no doc
  describes OKF depending on, importing, or naming Chorus.
- [critical] Chorus carries no `Organization` (or tenant/account) model of its
  own; the per-tenant database (`cnfs_tenanted`, one physical DB per
  `Iam::Account`) is the organizational boundary. Strategy, Role, Workspace, and
  Agent are top-level roots scoped by the database, not by an owning FK.
  referent: no `Organization`/`Tenant`/`Account` model or `chorus_organizations`
  table exists in the engine; no `chorus_*` model declares `belongs_to
  :organization`; docs describe no in-schema org root.

### identity / structure

- [high] The intent spine is a tree rooted at Strategy: Strategy → Goal →
  Project → Issue. Ownership flows down it; a Project reaches its Strategy through
  its Goal, never through a Workspace.
  referent: `Project belongs_to :goal` (not `:workspace`); docs/models give
  Workspace no structural claim on the Strategy→Project chain; each Goal belongs
  to exactly one Strategy.
- [high] Workspace is durable and serial: it hosts exactly one active Project at
  a time via the nullable `active_project_id`; there is no live Workspace↔Project
  many-to-many, and past-occupant history is not modelled.
  referent: `chorus_workspaces` has a single nullable `active_project_id`; docs
  describe no occupancy-history table (it is deferred to `doc/plans/003`).
- [high] Agent attaches to a Workspace only through the Issue claim — never a
  direct agent↔workspace FK. An Agent's workspace is found via
  `issue.project.hosting_workspace`.
  referent: `chorus_agents` carries no `workspace_id`; docs never describe a
  direct `Agent#workspace` association.
- [high] Artifact is first-class and type-open: a Workspace holds many Artifacts
  whose `kind` is a free string; Chorus special-cases no artifact kind or stack.
  referent: `Artifact#kind` is a plain string column; no doc or model branches on
  a specific kind value (`"git_repo"`, `"okf_bundle"`, Rails, Solana, …).

### hygiene

- [medium] Narrative content lives in OKF concepts via `has_one_okf`, never in a
  `body`/`content`/`markdown` column on a domain table (Strategy, Goal, Project,
  Issue).
  referent: no `chorus_*` domain table carries a body/content/markdown column; a
  model needing narrative content declares `has_one_okf`.
- [medium] `status`/`kind` are free strings (the host owns those vocabularies);
  `slug` appears only where it earns its place (`chorus_projects`).
  referent: schema uses string `status`/`kind` with no inclusion validation;
  `slug` exists only on `chorus_projects`.

### coherence of docs ↔ plans

- [medium] `doc/plans` holds unimplemented work only; shipped/superseded plans are
  retired to `chorus/.trash` (the space-root trash), not kept in the queue.
  referent: every file in `doc/plans` corresponds to work not yet green in the
  suite; no `PHASE-*.md` remains at the gem root.
- [medium] No doc or plan references a deleted file or superseded naming
  (`ARCHITECTURE-content-storage.md`, `PHASE-A*`/`PHASE-B`, "respine",
  "nine-model spine").
  referent: grep of docs + `doc/plans` for those names returns nothing.

### features in flux (provisional — not scored)

- **Model-layer stabilization** is an open arc. `AgentProfile` is committed to a
  single non-STI model whose runtime behavior is described by an attached OKF
  Concept (Rails STI is the documented, unbuilt fallback), but three things are
  unsettled: the Agent↔AgentProfile FK direction (today `AgentProfile has_many
  :agents` with no inverse `agent_profile_id` on `chorus_agents`), the
  commented-out `belongs_to :role` on `AgentProfile` and `Skill`, and the
  remaining pending Agent request specs. Claims about `AgentProfile`'s final
  shape and the Agent↔profile relationship are PROVISIONAL.
  tracking: `doc/plans/001-model-layer-stabilization.md`
- **Lifecycle integration and heartbeat/checkout** are open arcs. The end-to-end
  coordination lifecycle spec (`spec/integration/`) is not yet written, and Issue
  claim/lease/heartbeat columns do not exist — `Issue → Agent` is still a soft
  optional `belongs_to`. Claims about atomic claim/lease/heartbeat semantics are
  PROVISIONAL until these land.
  tracking: `doc/plans/002-lifecycle-integration.md`,
  `doc/plans/003-heartbeat-and-checkout.md`
