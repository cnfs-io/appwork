# patrol.md — chorus gem

Append-only coherence-patrol log, newest entry on top. Written by `docs-patrol`
(and the initial baseline by `docs-sheriff`). The scoring law and procedure live
in the space-root `COHERENCE.md`; the claims being checked live in the
`#coherence` section of this gem's `CLAUDE.md`.

---

## 2026-07-16T06:35 — sheriff reconciliation (post-004/005/006 reset)
run: session session_015rsicNqEEzDgAwSbknG4G4 · cwd /Users/robertroach/spikes/chorus/gems/chorus
commit: 4e609e4a12c7bfd2d38e0891057cb5a73645f008
        ⚠ checkpoint SHA — the reconciled docs below are UNCOMMITTED and sit AHEAD
        of this SHA (with the 004/005/006 code). The operator will commit next; the
        following patrol should run after that commit so the checkpoint reflects the
        reconciled state.

verdict: coherent
drift score: 0 (by construction — this pass reconciled the drift the 06:20 patrol found)

Ran `docs-sheriff` to reconcile chorus to reality after the 004/005/006 extraction
(the 06:20 patrol below scored it incoherent, drift 33). What was reconciled — not
"drift found," this is the reset:

### reconciliation performed
- **`CLAUDE.md` rewritten to the coordination-substrate reality.** "What Chorus is"
  now describes the execution surface + `Appwork::Chorus::Workable` + participants + skill
  catalog + sources, not an org-chart domain. The intent-spine ERD was replaced
  with the current model map; "Load-bearing invariants", "Layout", and the "Tests"
  note were rewritten (Workspace occupies a polymorphic `workable`; Agent carries
  no Role/workspace FK; scaffold V+C retired; request specs gone).
- **New host-agnostic boundary documented** — hosts depend on Chorus and include
  `Appwork::Chorus::Workable`; Chorus never names a host. Added as prose and a `[critical]`
  claim.
- **`#coherence` re-authored** (per `docs-author`): 3 boundary `[critical]`
  (OKF-direction, host-agnostic, no-Organization), 5 structural `[high]`
  (execution-surface-not-spine, Workspace-serial-workable, Workable-occupiability-
  only, Agent-no-workspace/Role, Artifact-type-open), 3 hygiene/docs-plans
  `[medium]`, 2 flux entries refreshed.
- **`ARCHITECTURE-testing-scope.md` reconciled** — Chorus's Claim 1.5 is now the
  *occupancy* lifecycle (synthetic workable ↔ Workspace); the org-derivation
  lifecycle is the host's. Thesis (harness-soundness vs. efficacy) preserved.
- **`README.md` truth-fixed** (targeted) — header + Domain no longer describe the
  departed org domain / "full CRUD"; theming & i18n flagged as future-UI; dev
  commands corrected. A full `readme-authoring` pass is deferred (see notes).
- **Shipped plans retired.** `005` and `006` (KICKOFF + main) moved to
  `chorus/.trash` (004 was already there). `doc/plans` now holds only unimplemented
  work: `001`, `002`, `003`.

### flagged for the operator (NOT resolved by sheriff)
- **Plans `002`/`003` are premised on the departed `Appwork::Chorus::Issue`.** They predate
  the extraction and describe Issue-based claim/lease/heartbeat in Chorus. Left in
  the queue but flagged in the lifecycle flux entry: they need re-scoping (host-side
  Ticket lifecycle, or a Workable-level lifecycle) before execution — an open design
  decision, not sheriff's to make.
- **`README.md` needs a full `readme-authoring` pass once the Phlex/Partitia::Ui UI
  lands** — it is user-facing and its UI sections describe a layer mid-rebuild;
  sheriff only truth-fixed the lies, it did not re-author it.
- **`micro_manager` is un-onboarded** — a real project born from plan 004 (models,
  specs, own `progress.md`) with no `#coherence` marker; its plans still live under
  `chorus/doc/plans`. Recommend a separate `docs-sheriff` onboarding.

### state (context, not scored)
- branched: no (trunk `main`)
- uncommitted: 117+ files — the 004/005/006 code plus this doc reconciliation;
  nothing committed. Reconciled docs sit ahead of the checkpoint SHA.
- suite: green — 125 examples, 0 failures, 0 disabled
- flux: 2 open arcs — (1) model-layer stabilization (`001`); (2) lifecycle +
  heartbeat/checkout (`002`/`003`, and see the re-scope flag above)

### notes
- No code bug found (no STOP): suite green; sheriff did not audit code.
- Next patrol: run after the operator's commit, so the checkpoint SHA captures the
  reconciled state and future drift is measured against it honestly.

---

## 2026-07-16T06:20 — patrol
run: session session_015rsicNqEEzDgAwSbknG4G4 · cwd /Users/robertroach/spikes/chorus/gems/chorus
commit: 4e609e4a12c7bfd2d38e0891057cb5a73645f008
        ⚠ checkpoint SHA. At this SHA the docs still COHERE — the drift below lives
        entirely in the UNCOMMITTED working tree (plans 004/005/006, 117 files),
        which sits ahead of it. The 2026-07-08 baseline already warned "run after a
        commit"; instead the extraction landed uncommitted on top, so patrol is
        again measuring a tree ahead of its checkpoint.

verdict: incoherent (working tree) — but see the uncommitted-WIP caveat
drift score: 33

Plans 004/005/006 (this session, uncommitted) extracted the entire intent spine
(Strategy/Goal/Project/Issue) and Role out of Chorus into `micro_manager`, and
replaced Workspace's `active_project` with a polymorphic `workable`. `CLAUDE.md`
(prose AND `#coherence`) was not updated, so most identity/structure claims now
name models absent from the engine. Settled-but-undocumented change: patrol raises
the flag, does not rewrite the claims. Recommend a `docs-sheriff` reconciliation
(the `#coherence` section needs re-authoring — sheriff's job), ideally right after
the 004/005/006 work is committed.

### critical

- [critical] "no Organization model; Strategy, Role, Workspace, Agent are
  top-level roots" — boundary core holds, enumeration contradicted. The
  load-bearing half (no `Organization`/`Tenant`/`Account` model or
  `appwork_chorus_organizations` table; database-is-the-org) still holds — verified, no
  such model on disk. But the claim names Strategy and Role as current Chorus
  roots; both left the engine in plan 004 (Strategy → `Appwork::Manager::Strategy`;
  Role deleted, IAM to provide it). Surfaced as critical because a `[critical]`
  claim's text now misdescribes the model set. Proposed fix (confirm via sheriff):
  narrow the enumeration to the roots that remain — Workspace and Agent (plus
  AgentProfile, Skill, Source, ExternalAccount, skill-catalog models); drop
  Strategy/Role. Leave the "no Organization" invariant untouched.
- The other `[critical]` — Chorus consumes OKF one-directionally — is intact:
  `grep -ri chorus` over `gems/okf/app|lib` is clean. No drift.

### drift

- [high] "intent spine rooted at Strategy: Strategy → Goal → Project → Issue."
  Referent `Project belongs_to :goal` fails — no `Appwork::Chorus::Project` (nor
  Strategy/Goal/Issue) on disk; the spine moved to `micro_manager` (plan 004).
  Fix: remove the intent-spine ERD from Chorus's docs; it is now `micro_manager`'s.
- [high] "Workspace hosts one active Project via nullable `active_project_id`."
  Referent fails — `appwork_chorus_workspaces` has no `active_project_id`; it carries
  polymorphic `workable_id`/`workable_type` (004/005). Fix: restate as "Workspace
  occupies one polymorphic `workable` via `belongs_to :workable, polymorphic:,
  optional:` (the `Appwork::Chorus::Workable` contract); no `active_project` FK."
- [high] "Agent attaches to a Workspace only through the Issue claim
  (`issue.project.hosting_workspace`)." Narrow referent ("`appwork_chorus_agents` has no
  `workspace_id`") holds, but the mechanism is gone: Issue left the gem,
  `hosting_workspace` no longer exists. Fix: restate without Issue (occupancy is
  workable-mediated, host-side), or relocate to `micro_manager`.
- [medium] "slug appears only where it earns its place (`appwork_chorus_projects`)."
  Referent fails — `appwork_chorus_projects` is gone; `slug` now lives (uniquely) on
  `appwork_chorus_taxonomies`. Fix: "`slug` on `appwork_chorus_taxonomies` (normalized category key)."
- [medium] "Narrative content never in a body/content column on
  Strategy/Goal/Project/Issue." Referent (no such column) holds, but names four
  departed models. Fix: re-scope to Chorus-owned models, or state generally.

### docs ↔ plans

- Shipped plans still in queue. `005-workable-concern-and-status.md` and
  `006-status-separated-every-node-workable.md` (+ `006-KICKOFF.md`) executed green
  this session but remain in `doc/plans`; the `#coherence` convention retires
  shipped/superseded plans to `chorus/.trash`. Plan 004 was retired
  (`.trash/004-org-extraction-and-mvc-teardown.md`) — inconsistent application.
  Action: retire 005 and 006 to `.trash`. Context: the operator signalled an intent
  to revise the "retire to `.trash`" convention itself — if so, this claim and
  these files should be reconciled together (sheriff).
- [low/debatable] `progress.md` references superseded names
  (`PHASE-A2-domain-respine`, `PHASE-A2b-external-accounts`, "respine") — the "no
  superseded naming" referent greps these to zero, but `progress.md` is an
  append-only history where such names are expected. Action: exclude `progress.md`
  history from that referent, or accept the historical hits.

### state (context, not scored)

- branched: no (trunk `main`)
- uncommitted: 117 files — the entire 004/005/006 extraction is uncommitted;
  nothing committed since the checkpoint SHA. Dominant reading: docs-lag-code, WIP.
- suite: green — 125 examples, 0 failures, 0 disabled (no xit/xdescribe/pending)
- flux: 2 open entries — (1) Model-layer stabilization (tracking `001`, not
  executed); (2) Lifecycle/heartbeat (tracking `002`/`003`, not executed). Both
  legitimately open, so provisional claims not scored — but both premises now
  reference departed models: the model-layer parenthetical ("no inverse
  `agent_profile_id` on `appwork_chorus_agents`") is stale (plan 004 added it), and the
  lifecycle entry rests on `Issue → Agent`, which left the gem. Not stale-flux
  (tracked plans aren't green); flag for rewrite when 001/002/003 are revisited.

### notes

- Sheriff-sized, not piecemeal. Beyond the scored claims, the whole `CLAUDE.md`
  body is pre-004: "What Chorus is" (spine narrative), both ERD blocks,
  "Load-bearing invariants" (Issue-claim / active_project framing), and the
  "Layout" model list (names strategy/goal/project/issue/role; omits
  catalog_skill/curation/taxonomy/skill_categorization and the `Workable` concern).
  Recommend `docs-sheriff` on chorus to re-author `#coherence` and reconcile the
  prose in one pass, after committing 004/005/006.
- `micro_manager` is a real project born from plan 004 and appears un-onboarded —
  models, specs, and its own `progress.md`, but its plans live under
  `chorus/doc/plans` and it carries no `#coherence` marker. Out of scope for this
  (chorus) patrol; worth a `docs-sheriff` onboarding so it becomes patrollable.
- No code bugs found (no STOP): suite green, and patrol did not audit code.

---

## 2026-07-08T15:37:43Z — sheriff baseline (onboarding)
commit: 653aed04428a00dfc6c955dedd129b84b93b42e6
        ⚠ checkpoint SHA — the reconciled docs below are UNCOMMITTED and sit
        AHEAD of this SHA. The next patrol should run after a commit so this
        checkpoint reflects the reconciled state.

verdict: coherent
drift score: 0

This is the onboarding baseline. `docs-sheriff` reconciled the gem's docs to
reality before authoring the `#coherence` section, so drift is 0 by construction.
The reconciliation performed (not "drift found" — this is the reset):

- **Organization removed from all docs.** The working tree had already removed the
  `Organization` model, table, specs, factories, controllers, and views (suite
  green without them); `CLAUDE.md`, `README.md`, `ARCHITECTURE-testing-scope.md`,
  and plan 002 still described an Organization-rooted spine. Per an explicit
  operator decision, the removal is **settled**: the per-tenant database
  (`partitia-tenanted`, one DB per `Partitia::Iam::Account`) is the organizational boundary, and
  Strategy/Role/Workspace/Agent are top-level roots. All docs rewritten to match,
  present tense.
- **Dead references fixed.** `ARCHITECTURE-content-storage.md` (retired) and
  `PHASE-A*`/`PHASE-B` naming removed from `ARCHITECTURE-testing-scope.md` and
  plans 002/003; "respine"/"nine-model" language updated to present state.
- **Retired docs preserved.** The old root-level phase docs
  (`PHASE-A-chorus-domain.md`, `PHASE-A3-lifecycle-integration.md`,
  `PHASE-B-heartbeat-and-checkout.md`, `ARCHITECTURE-content-storage.md`) were
  already staged for deletion; copied from HEAD into
  `chorus/.trash/chorus-gem-phase-docs/` for recoverability.
  (`PHASE-A2-domain-respine.md` was already in `chorus/.trash/`.)
- **`#coherence` section authored** in `CLAUDE.md` (`level: project`): 2 boundary
  `[critical]`, 4 structural `[high]`, 4 hygiene/docs-plans `[medium]`, and 2 flux
  entries.
- **Level markers added** so patrol can reach here: `level: space` on
  `chorus/CLAUDE.md`, `level: area` on `gems/CLAUDE.md`.

### state (context, not scored)
- uncommitted: 99 files (the pre-existing Organization-removal refactor + this
  onboarding's doc reconciliation; nothing committed yet)
- branched: no (on `main`, the trunk)
- suite: green (144 examples, 0 failures, 8 pending)
- flux: 2 open arcs —
  - model-layer stabilization (tracking `doc/plans/001-model-layer-stabilization.md`)
  - lifecycle integration + heartbeat/checkout (tracking `doc/plans/002`, `doc/plans/003`)

### notes
- **Not a code bug — flux, documented.** `AgentProfile has_many :agents` currently
  has no inverse FK (`appwork_chorus_agents` carries `agent_id`, not `agent_profile_id`),
  so that association does not resolve. This is the *explicit open question* plan
  001 turns on ("Agent↔AgentProfile FK direction"), no spec exercises it, and the
  suite is green — so it is tracked flux, not an incidental bug. If plan 001
  closes without resolving it, a future patrol should escalate.
- The 8 pending Agent request specs are the tail of plan 001 ("no disabled or
  pending Agent specs remain" is in its definition of done) — expected to clear
  when 001 lands, at which point the model-layer flux entry should be closed by CC.
- Next patrol: run after the working tree is committed, so the checkpoint SHA
  captures the reconciled state and drift can be measured against it honestly.
