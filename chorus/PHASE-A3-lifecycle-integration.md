# PHASE A3 — Lifecycle integration spec (synthetic domain)

## Why this plan exists

Chorus's specs currently prove each model in isolation (associations,
validations, `dependent:` behavior) and each controller's CRUD. What is *not* yet
proven is that the nine models **compose into a working coordination lifecycle
end to end**. That is the strongest claim Chorus can honestly make about itself
as a harness (see `ARCHITECTURE-testing-scope.md`, "Claim 1.5"), and it is the
thing that de-risks the harness before Factory leans on it.

This plan adds a single, focused integration spec that walks a full coordination
cycle against a **synthetic, deliberately meaningless domain**. It asserts that
the *mechanics* flow — never that the work was useful (efficacy is a downstream
concern Chorus cannot test).

## Scope and hard boundaries

- **Tests current mechanics only.** As of today, Issue assignment is a plain
  `belongs_to :agent, optional: true` and lifecycle state is the free-string
  `status` column. There are **no** claim/lock/lease columns yet — those are
  PHASE-B. This spec must exercise the lifecycle as currently built: assignment
  by setting `agent`, progression by setting `status` strings. Do **not**
  introduce claim semantics here; leave clearly-marked extension points for when
  PHASE-B lands.
- **Synthetic domain, kept meaningless on purpose.** Use an obviously toy domain
  ("Acme Widgets"; a goal like "Ship the blue widget"; an issue like "Paint the
  widget blue"). The meaninglessness is the safeguard: it keeps the spec from
  encoding opinions about any real domain. Do not model a plausible real org.
- **No efficacy assertions.** The spec never asserts that output is good, useful,
  or correct in domain terms. It asserts only that the harness's parts mesh:
  records connect, the active slot behaves serially, assignment works, state
  transitions persist and resolve, the intent spine resolves both directions.
- **No content storage.** Per `ARCHITECTURE-content-storage.md`, the lifecycle
  does not need real content. Any narrative content in the synthetic domain is a
  trivial inline string on a non-persisted test variable or simply omitted. Do
  **not** add content columns or reach for a storage seam.
- **String `status` vocabulary is test-local.** Since `status` is a free string
  with no model-level inclusion validation, the spec defines whatever status
  values it uses (e.g. `"open"`, `"in_progress"`, `"done"`) purely as test
  fixtures. This is not a declaration of canonical Chorus states — it is the
  synthetic domain choosing words. Keep it that way.

## Where it lives

New directory `spec/integration/chorus/`, file
`coordination_lifecycle_spec.rb`. Type `:model` (pure ActiveRecord composition,
no HTTP) unless a step genuinely needs request-level exercise — it should not.
Use the existing FactoryBot factories; do not add new ones unless a factory is
missing a trait the lifecycle needs (if so, add the trait, in the same step,
per the move-factories-with-changes rule).

## The lifecycle to walk

One `describe` block, a sequence of phases. Each phase is a small group of
expectations against the same built graph (use `let!`/`before` to assemble the
synthetic org once, then assert the cycle).

### Phase 1 — Stand up the organization and intent spine
- Create an Organization ("Acme Widgets") with a Strategy ("Dominate widgets").
- Strategy spins up a Goal ("Ship the blue widget").
- Goal spins up a Project ("Blue widget v1").
- Project spins up two Issues ("Paint the widget blue", "Test the blue paint").
- **Assert the spine resolves downward**: `organization.strategies`,
  `strategy.goals`, `goal.projects`, `project.issues` all return the expected
  records.
- **Assert the spine resolves upward**: from an Issue, reach the Organization via
  `issue.project.goal.strategy.organization` (and via any `has_one :organization,
  through:` helpers that exist on Project/Goal). This proves the "why" lineage is
  reachable from a unit of work — the harness property that lets an agent see the
  goal behind a task.

### Phase 2 — Stand up the execution surface
- Create a Workspace ("Widget Lab") belonging to the Organization.
- Attach two Artifacts of different `kind` (e.g. `"git_repo"` and `"okf_bundle"`)
  with locators — proving the workspace holds heterogeneous artifacts without
  Chorus blessing either type.
- **Assert** `workspace.artifacts` returns both and that `active_project` is
  currently nil (nothing is being worked yet).

### Phase 3 — Take the project into the workspace (serial occupancy)
- Set `workspace.active_project = project` (the Blue widget project).
- **Assert** the workspace now hosts exactly that project via `active_project`,
  and the inverse resolves: `project.hosting_workspace == workspace`.
- **Assert serial discipline**: with this workspace's slot occupied, taking on a
  *second* project means the active slot moves to the new project (set
  `active_project` to a second project and confirm the first is no longer the
  active occupant). This documents the "one active project at a time" rule as a
  behavioral expectation. (History of the displaced project is **not** asserted —
  history is deferred to PHASE-B; assert only that the slot now holds the new
  project.)

### Phase 4 — Participants meet the work
- Create a Role ("Maker") and two Agents — one `kind: "ai"`, one `kind: "human"`
  — in the Organization; assign the Maker role to at least one.
- Assign Issues to Agents by setting `issue.agent`.
- **Assert** assignment resolves both ways: `issue.agent` and `agent.issues`.
- **Assert the agent reaches the workspace only through the issue** — i.e. there
  is no direct `agent.workspace`; the agent's execution context is found via
  `issue.project.hosting_workspace`. This is the explicit verification of the
  "agent attachment is mediated by the Issue claim" invariant: confirm
  `Chorus::Agent` has no `workspace` association and no `workspace_id` column.

### Phase 5 — Run the work through to resolution
- Walk each Issue's `status` through the synthetic vocabulary:
  `"open" → "in_progress" → "done"`, persisting each transition.
- **Assert** transitions persist and are queryable (e.g. all issues for the
  project eventually `status == "done"`).
- **Assert resolution**: once every issue is `"done"`, the project can be marked
  `status: "done"` and the workspace's active slot can be freed
  (`workspace.update!(active_project: nil)`) — proving the workspace returns to
  available for reuse. This closes the cycle: durable workspace, transient
  project occupancy.

### Phase 6 — Teardown integrity (dependent behavior across the whole graph)
- **Assert** the destroy cascade behaves coherently end-to-end on the synthetic
  graph: destroying the Organization (or the relevant parents) removes dependent
  records per each model's declared `dependent:` option, and nullifies where
  declared (e.g. an Agent's role, an Issue's agent). This is the integration-level
  counterpart to the per-model `dependent:` unit specs — it proves they compose
  without orphan/FK surprises.

## Extension points to mark (for PHASE-B, do not build now)

Leave explicit `# PHASE-B:` comments where the lifecycle will deepen, so the
future work has obvious seams:
- Phase 4 assignment becomes an **atomic claim** (claim_state, lease, the guarded
  `update_all` race). The current `issue.agent = agent` is the pre-claim form.
- Phase 5 progression gains **lease renewal / expiry / orphan release**.
- Phase 3 gains **occupancy history** (the displaced project is recorded, not
  forgotten).
A short comment block at the top of the spec should note that this file is
expected to grow these capabilities when PHASE-B lands.

## Done when

- `spec/integration/chorus/coordination_lifecycle_spec.rb` exists and is green.
- The full cycle (Phases 1–6) runs against one synthetic org in one spec file.
- No efficacy assertion appears anywhere in the file.
- No content column, storage seam, or claim/lock column is introduced.
- The spec asserts the three harness invariants explicitly: upward spine
  resolution (Issue → Organization), serial workspace occupancy, and
  agent-reaches-workspace-only-through-issue (no `agent.workspace`).
- `bin/ci` green overall.
- A `progress.md` entry (Phase A3) is appended per the shared progress-file
  convention, flagging any place the lifecycle didn't compose as expected and how
  it was resolved.
```
