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

A mountable Rails engine (`isolate_namespace Appwork::Chorus`) that provides the
**coordination substrate** for human/AI participant work — not an org-chart domain
of its own. Chorus owns:

- the **execution surface**: a durable, serial `Workspace` that occupies one
  polymorphic *workable* at a time and holds `Artifact`s;
- the **`Appwork::Chorus::Workable`** occupiability contract a host domain model `include`s
  to become occupiable by a Workspace;
- **participants**: `Agent` and `AgentProfile`;
- a **skill catalog** (`CatalogSkill`, `Curation`, `Taxonomy`,
  `SkillCategorization`, `Skill`) mirroring the external agent-skills ecosystem;
- **managed origins & third-party accounts**: `Source` and `ExternalAccount` (STI).

**Chorus does not own the org-chart spine.** The intent spine
(strategy → goal → project → issue) and `Role` were extracted to host gems: the
org spine lives in a host like `micro_manager`; IAM provides `Role`. A host
becomes occupiable by depending on Chorus and including `Appwork::Chorus::Workable` (see
the host-agnostic boundary below). Chorus holds **no `Organization` row of its
own** — a Chorus database *is* one organization. Chorus stays non-opinionated — it
limits its opinions so as not to rule out legitimate setups (e.g. a single unit of
work needing both a Rails repo and a Solana repo).

## The boundary that defines Chorus

**Chorus consumes OKF; OKF never knows Chorus.** This one-directional
dependency is the single most important invariant. Chorus owns its entire
database schema with real foreign keys between `chorus_*` tables, and on top of
that it is an OKF *consumer*: `Appwork::Chorus::ApplicationRecord` includes
`Appwork::Okf::Consumer`, so every Chorus record is OKF-consumer-capable by design.
Models opt into actual concept-backing with `has_one_okf` where it earns its
place (today `Skill has_one_okf :concept`). The dependency runs strictly one
way — Chorus may reference OKF constants and macros; **OKF must never reference,
name, or know about Chorus** (grep-enforceable: no `chorus` in `okf/`).

This reverses the engine's earlier "OKF-naive" stance (Chorus once owned no OKF
coupling at all). What survived the reversal is the *directionality*, not the
absence of coupling: the sacred rule is now "Chorus→OKF allowed, OKF→Chorus
forbidden," not "no coupling."

### The host boundary: hosts depend on Chorus; Chorus knows no host

Chorus is **host-agnostic**. A host domain gem (today `micro_manager`; tomorrow
`gtd`, or a bare Concept-backed unit) is a **Chorus consumer**: it depends on
Chorus and `include`s `Appwork::Chorus::Workable` to make its domain models occupiable —
exactly as it `include`s `Appwork::Okf::Consumer` to become OKF-backed. The dependency
runs strictly one way:

- **Host → Chorus:** allowed, real, gemspec-declared. A host may reference
  `Appwork::Chorus::Workable`, `Appwork::Chorus::Workspace`, `Appwork::Chorus::Agent`.
- **Chorus → any host:** FORBIDDEN. Chorus must never reference, name, or know a
  host constant (`Appwork::Manager`, `Gtd`, …). This is what the org-spine extraction
  was *for* — so one Chorus can serve any host.

(grep-enforceable: no host constant appears under `gems/chorus/app` or
`gems/chorus/lib`.) This is the same shape as the OKF rule, one boundary over.

### The organization boundary: a database is an organization

Chorus carries **no `Organization` model, table, or owning FK.** The
organizational boundary is the **database**: under `partitia-tenanted` there is one
physical database per `Partitia::Iam::Account`, and that per-account database *is* one
organization. Every `chorus_*` record already lives inside exactly one org by
virtue of which database it is in, so an `Organization` row would only restate
what the connection already guarantees — and would invite cross-org rows in a
single table, which the tenancy model exists to prevent.

The consequence for the schema: **Workspace and Agent are top-level roots** — no
`chorus_*` model `belongs_to :organization`, because there is no organization row
to belong to. `Source` and `ExternalAccount` say the same in their own comments
("account-scoped by tenancy — one physical DB per Account"). Do not reintroduce an
`Organization` model or an org-owning FK; scope is the database, not a column.

### Corollary: no content columns on domain tables

A model that carries narrative content does **not** get a
`body`/`content`/`markdown` column. Narrative content lives in OKF concepts,
reached via `has_one_okf`. A `body` column would be a competing source of truth
against the OKF concept — a two-master sync problem — so the binding rule is
simply: **add no content columns.** A model that needs narrative content declares
`has_one_okf` and lets the OKF concept own the text. (This is why the
now-extracted spine models never carried a `body` column, and why host spine
models don't either.)

## The domain (current model map)

Chorus owns the **execution surface** and **participants**, plus a skill catalog
and managed-origin models. The **intent spine (strategy → goal → project → issue)
is not here** — it lives in host gems; Chorus sees only a polymorphic *workable*.

Execution surface (top-level roots — no owner FK; scoped by the database):

```
Workspace       durable; occupies ONE workable at a time (serial)
  belongs_to :workable, polymorphic: true, optional: true  — the occupied slot
  has_many   :artifacts (destroy)
Artifact        belongs_to :workspace
  first-class; string `kind` (e.g. "git_repo", "okf_bundle"); a `locator`
  Chorus blesses no artifact type — new kinds are added by convention
```

`Appwork::Chorus::Workable` (`app/models/concerns/chorus/workable.rb`) — the occupiability
contract a host model includes:

```
Workable (concern)  include-d by a host domain model
  provides has_one :workspace, as: :workable (the polymorphic inverse)
  OCCUPIABILITY ONLY — carries no status, no host-domain semantics
```

Participants (top-level roots):

```
Agent           has_one_okf :concept  (no direct workspace FK; no Role — IAM owns Role)
AgentProfile    has_many :agents (nullify); has_one_okf :concept
                (Agent↔AgentProfile FK direction is being settled — see plan 001)
```

Skill catalog (mirror of the external agent-skills ecosystem):

```
CatalogSkill        has_many :taxonomies, through: :skill_categorizations
Taxonomy            self-referential parent/children; slug-keyed
SkillCategorization belongs_to :catalog_skill, :taxonomy
Curation            chorus.org's reputation verdict (YAML-serializable)
Skill               minimal; has_one_okf :concept
```

Managed origins & third-party accounts (STI, `settings`-bag config):

```
Source            STI base (Source::Git live) — a managed origin synced to disk
ExternalAccount   STI base (ExternalAccount::GitHub acts) — a tenant's 3rd-party accounts
```

## Load-bearing invariants

- **Chorus provides the execution surface, not the intent spine.** The domain
  spine (strategy → goal → project → issue) lives in host gems; Chorus owns
  `Workspace` and the `Appwork::Chorus::Workable` contract. Do not reintroduce spine models
  into Chorus.
- **Workspace is durable and serial.** It outlives any single occupant and
  occupies one polymorphic `workable` at a time via the nullable
  `workable_id`/`workable_type`. This is deliberate: serial reuse prevents
  concurrent occupants from clobbering each other's artifacts. Do not model
  Workspace↔workable as a live many-to-many. Past-occupant *history* is
  deliberately not modelled yet — parked in `doc/plans/003-heartbeat-and-checkout.md`.
- **`Appwork::Chorus::Workable` is occupiability only.** It provides the polymorphic
  `has_one :workspace, as: :workable` inverse and nothing else — no status, no
  host-domain semantics. Status is a separate host-side facility
  (`okf_frontmatter :status` over the OKF concept), not Workable's job.
- **Artifact is first-class and type-open.** A workspace holds many artifacts
  (multiple repos, OKF bundles) of different `kind`s. Chorus must never special-
  case a particular stack (Rails, Solana, etc.); that is what keeps Chorus
  unopinionated.
- **Agent carries no direct workspace FK.** An Agent does *not* carry a
  `workspace_id`; agent↔workspace is discovered host-side (via the host's
  occupancy of a workspace), never a direct FK in Chorus. Agent also carries no
  `Role` — IAM owns Role.
- **`kind` is a free string; `slug` only where it earns its place** (`appwork_chorus_taxonomies`,
  the normalized category key). The host owns `status` vocabularies — Chorus
  carries no `status` column.

## Layout

- `app/models/chorus/` — the execution surface (`workspace`, `artifact`),
  participants (`agent`, `agent_profile`), the skill catalog (`catalog_skill`,
  `curation`, `taxonomy`, `skill_categorization`, `skill`), and origins/accounts
  (`source`, `external_account`). There is no `organization` model, and no spine
  models (`strategy`/`goal`/`project`/`issue`/`role`) — those live in host gems.
- `app/models/concerns/chorus/workable.rb` — the occupiability contract a host
  domain model includes (the polymorphic `has_one :workspace, as: :workable`).
- `app/models/chorus/source.rb` (+ `source/`) — an STI base (`Source::Git` live)
  whose per-kind config lives in a serialized `settings` bag (the `setting`
  macro), not per-kind columns.
- `app/models/chorus/external_account.rb` (+ `external_account/`) — an STI base
  (`ExternalAccount::GitHub` acts; `Gitlab`/`Aws`/`GoogleCloud` are data-only)
  for a tenant's third-party service accounts; same `settings`-bag pattern.
- `app/controllers/appwork/chorus/` — `application_controller` only; the scaffold V+C
  layer was retired (plan 004), to be rebuilt on Phlex/Partitia::Ui later.
- `db/migrate/` — edited in place pre-v1 (see `../CLAUDE.md`).
- `config/locales/en.yml` — `chorus.*` namespace. `es.yml` lives in
  `spec/dummy/config/locales/`.
- `spec/` — RSpec + FactoryBot; model specs under `spec/models/chorus/` (request
  specs were retired with the scaffold V+C layer; they return when Phlex UI does).

## Tests

Run with `bin/rails` against `spec/dummy`, or `bin/ci`. When a model changes,
move its factory (`spec/factories/chorus_*.rb`) and specs in the same step as
the in-place migration edit, so schema and fixtures stay together.

**Test only what a harness can honestly claim.** Chorus tests that the harness is
internally sound and that a full coordination lifecycle composes end-to-end
against a *synthetic* domain (the end-to-end lifecycle spec is not yet written —
see the flux entries below). Chorus never tests *efficacy* ("did this produce
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
  constants and macros (`Appwork::Chorus::ApplicationRecord` includes `Appwork::Okf::Consumer`;
  models opt in with `has_one_okf`), but OKF must never reference, name, or know
  about Chorus.
  referent: `grep -ri chorus` under the `okf` gem returns nothing; no doc
  describes OKF depending on, importing, or naming Chorus.
- [critical] Chorus is host-agnostic: hosts depend on Chorus and `include`
  `Appwork::Chorus::Workable` to become occupiable, but Chorus never references, names, or
  knows a host constant (`Appwork::Manager`, `Gtd`, …). The dependency runs
  host → Chorus only; Chorus → host is forbidden.
  referent: grep for host constants (`Appwork::Manager`, `Gtd`, …) under
  `gems/chorus/app` and `gems/chorus/lib` returns nothing; no `chorus_*` model or
  doc names a host gem.
- [critical] Chorus carries no `Organization` (or tenant/account) model of its
  own; the per-tenant database (`partitia-tenanted`, one physical DB per
  `Partitia::Iam::Account`) is the organizational boundary. Workspace and Agent are
  top-level roots scoped by the database, not by an owning FK.
  referent: no `Organization`/`Tenant`/`Account` model or `appwork_chorus_organizations`
  table exists in the engine; no `chorus_*` model declares `belongs_to
  :organization`; docs describe no in-schema org root.

### identity / structure

- [high] Chorus provides the execution surface, not the intent spine. The domain
  spine (strategy → goal → project → issue) lives in host gems; Chorus owns the
  `Workspace` execution surface and the `Appwork::Chorus::Workable` occupiability contract.
  referent: no `Strategy`/`Goal`/`Project`/`Issue` model exists in the engine; the
  `Appwork::Chorus::Workable` concern exists; `Appwork::Chorus::Workspace belongs_to :workable,
  polymorphic: true`.
- [high] Workspace is durable and serial: it occupies exactly one polymorphic
  workable at a time via the nullable `workable_id`/`workable_type`; there is no
  live Workspace↔workable many-to-many, and past-occupant history is not modelled.
  referent: `appwork_chorus_workspaces` carries polymorphic `workable_id`/`workable_type`
  (and no `active_project_id`); docs describe no occupancy-history table (deferred
  to `doc/plans/003`).
- [high] `Appwork::Chorus::Workable` is occupiability only: it provides the polymorphic
  `has_one :workspace, as: :workable` inverse and carries no status or host-domain
  semantics. Status is a separate host-side facility (`okf_frontmatter :status`
  over the OKF concept), not Workable's.
  referent: `Appwork::Chorus::Workable` declares only the `workspace` inverse (no `status`
  accessor); docs describe status as a host-side `okf_frontmatter` facility.
- [high] Agent carries no direct workspace FK, and no `Role`. Agent↔workspace is
  discovered host-side, never a direct FK in Chorus; `Role` left Chorus (IAM owns
  it).
  referent: `appwork_chorus_agents` carries no `workspace_id` and no `role_id`; no
  `Appwork::Chorus::Agent#workspace` or `belongs_to :role` exists; no `Appwork::Chorus::Role` model.
- [high] Artifact is first-class and type-open: a Workspace holds many Artifacts
  whose `kind` is a free string; Chorus special-cases no artifact kind or stack.
  referent: `Artifact#kind` is a plain string column; no doc or model branches on
  a specific kind value (`"git_repo"`, `"okf_bundle"`, Rails, Solana, …).

### hygiene

- [medium] Narrative content lives in OKF concepts via `has_one_okf`, never in a
  `body`/`content`/`markdown` column on a `chorus_*` table.
  referent: no `chorus_*` table carries a body/content/markdown column; a model
  needing narrative content declares `has_one_okf`.
- [medium] `kind` is a free string (the host owns those vocabularies); `slug`
  appears only where it earns its place (`appwork_chorus_taxonomies`); Chorus carries no
  `status` column (status is a host-side concept-frontmatter concern).
  referent: schema uses string `kind` with no inclusion validation; `slug` exists
  only on `appwork_chorus_taxonomies`; no `chorus_*` table has a `status` column.

### coherence of docs ↔ plans

- [medium] `doc/plans` holds unimplemented work only; shipped/superseded plans are
  retired to `chorus/.trash` (the space-root trash), not kept in the queue.
  referent: every file in `doc/plans` corresponds to work not yet green in the
  suite; no shipped plan (e.g. 004/005/006) remains in the queue; no `PHASE-*.md`
  at the gem root.
- [medium] No live doc references a deleted file or superseded naming
  (`ARCHITECTURE-content-storage.md`, `PHASE-A*`/`PHASE-B`, "respine",
  "nine-model spine").
  referent: grep of `CLAUDE.md`, `README.md`, `ARCHITECTURE-*.md`, and `doc/plans`
  for those names returns nothing (the append-only `progress.md` history is exempt
  — it records past state by design).

### features in flux (provisional — not scored)

- **Model-layer stabilization** is an open arc. `AgentProfile` is committed to a
  single non-STI model whose runtime behavior is described by an attached OKF
  Concept (Rails STI is the documented, unbuilt fallback), but two things are
  unsettled: the Agent↔AgentProfile FK direction (plan 004 added an
  `agent_profile_id` column to `appwork_chorus_agents`, but `Appwork::Chorus::Agent` declares no
  `belongs_to :agent_profile` yet — only `AgentProfile has_many :agents`), and the
  commented-out `belongs_to :role` on `AgentProfile` and `Skill` (now stale
  placeholders — `Role` has left Chorus, so these must be resolved or removed).
  Claims about `AgentProfile`'s final shape and the Agent↔profile relationship are
  PROVISIONAL.
  tracking: `doc/plans/001-model-layer-stabilization.md`
- **Lifecycle integration and heartbeat/checkout** are open arcs. The end-to-end
  coordination lifecycle spec is not yet written, and claim/lease/heartbeat
  semantics do not exist. NOTE: plans 002 and 003 predate the org extraction and
  are premised on the now-departed `Appwork::Chorus::Issue` — they need re-scoping to the
  post-extraction world (host-side Ticket lifecycle, or a Workable-level
  lifecycle) before execution; that re-scope is an open operator decision. Claims
  about atomic claim/lease/heartbeat semantics are PROVISIONAL until these land.
  tracking: `doc/plans/002-lifecycle-integration.md`,
  `doc/plans/003-heartbeat-and-checkout.md`
