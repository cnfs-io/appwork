# patrol.md — chorus gem

Append-only coherence-patrol log, newest entry on top. Written by `docs-patrol`
(and the initial baseline by `docs-sheriff`). The scoring law and procedure live
in the space-root `COHERENCE.md`; the claims being checked live in the
`#coherence` section of this gem's `CLAUDE.md`.

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
  (`cnfs_tenanted`, one DB per `Iam::Account`) is the organizational boundary, and
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
  has no inverse FK (`chorus_agents` carries `agent_id`, not `agent_profile_id`),
  so that association does not resolve. This is the *explicit open question* plan
  001 turns on ("Agent↔AgentProfile FK direction"), no spec exercises it, and the
  suite is green — so it is tracked flux, not an incidental bug. If plan 001
  closes without resolving it, a future patrol should escalate.
- The 8 pending Agent request specs are the tail of plan 001 ("no disabled or
  pending Agent specs remain" is in its definition of done) — expected to clear
  when 001 lands, at which point the model-layer flux entry should be closed by CC.
- Next patrol: run after the working tree is committed, so the checkpoint SHA
  captures the reconciled state and drift can be measured against it honestly.
