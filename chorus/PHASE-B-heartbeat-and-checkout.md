# NEXT — heartbeat + atomic issue checkout

**Status: parked.** Do not start this until `PHASE-A2-domain-respine.md` is green
and merged. It builds on the respun nine-model domain and changes the `Issue` →
`Agent` relationship from a simple optional `belongs_to` into a proper claim.

This is the Chorus translation of two patterns proven by Paperclip
(MIT-licensed agent orchestrator): **heartbeats** (agents wake on a schedule or
event, check a queue, act, sleep) and **atomic task checkout** (claim + budget
enforced in one transaction so no double-work and no runaway spend). The concepts
are lifted; the implementation is idiomatic Rails 8.1 / Solid Queue / SQLite.

The two patterns touch two tables — `chorus_agents` (heartbeat) and
`chorus_issues` (checkout). Both are stable after the respine, which is why this
was safe to defer. Read Paperclip's actual checkout transaction before
implementing the claim; the correctness subtleties there are the whole point.

## Part 1 — Heartbeat (chorus_agents)

An Agent does not run continuously. It wakes on a cadence or an event, checks for
claimable work, acts, and sleeps. Decouple three concerns: the Agent *owns* a
cadence; a scheduler *enqueues* wakeups; a runner *executes* one wakeup.

### Columns to add to `chorus_agents` (edit in place pre-v1)

```ruby
t.string   :heartbeat_state, null: false, default: "idle"
           # "idle" | "scheduled" | "running" | "paused"
t.integer  :heartbeat_interval_seconds      # nil = event-only, no schedule
t.datetime :last_heartbeat_at               # last wake actually executed
t.datetime :next_heartbeat_at               # when the scheduler should wake it
```

Index `next_heartbeat_at` (partial, where `heartbeat_state = 'scheduled'`) so the
scheduler scan is cheap.

### Wakeup mechanics

- **Scheduler**: a recurring Solid Queue job scans agents whose
  `next_heartbeat_at <= now` and `heartbeat_state = 'scheduled'`, and enqueues
  one `Chorus::AgentHeartbeatJob` per agent.
- **Coalescing**: never stack two pending wakeups for one agent. Before
  enqueuing, transition `scheduled → running` with a guarded update
  (`UPDATE ... WHERE heartbeat_state = 'scheduled'`); only the row that actually
  flipped gets a job. This is the heartbeat analogue of the issue claim below.
- **Event triggers**: assigning an issue or @-mentioning an agent enqueues an
  immediate `AgentHeartbeatJob` regardless of schedule (same coalescing guard).
- **Recompute**: on completing a wake, set `last_heartbeat_at = now`,
  `next_heartbeat_at = now + interval` (if interval present), and state back to
  `scheduled` (or `idle` if event-only).
- **Orphan recovery**: an agent stuck in `running` past a lease horizon (e.g. no
  `last_heartbeat_at` update within N× interval) is swept back to `scheduled`
  and any issue it had claimed is released (see below). This is the heartbeat
  half of crash recovery.

## Part 2 — Atomic issue checkout (chorus_issues)

The claim is the hard correctness detail. Two agents must never work the same
issue; a claim must survive an agent crash without leaking. Today
`Issue belongs_to :agent, optional: true` is a soft pointer — it becomes a
leased claim.

### Columns to add to `chorus_issues` (edit in place pre-v1)

```ruby
t.string   :claim_state, null: false, default: "open"
           # "open" | "claimed" | "in_progress" | "done" | "abandoned"
t.datetime :claimed_at
t.datetime :claim_expires_at        # lease horizon; nil when open
# agent_id already exists (the optional belongs_to) — it now records the claimant
```

Index `[claim_state, project_id]` for "claimable issues in this project", and
`claim_expires_at` (partial, where `claim_state IN ('claimed','in_progress')`)
for the lease sweeper.

### The claim transaction

A claim is a single atomic transaction. In SQLite under Rails, use a row lock via
`with_lock` (SQLite serialises writes; combine with the guarded conditional
update so the claim is decided by the DB, not by read-then-write in Ruby):

```ruby
# Chorus::Issue
def self.claim_next_for(agent, project:, lease: 15.minutes)
  transaction do
    issue = where(project_id: project.id, claim_state: "open")
              .order(:position, :id)
              .lock("FOR UPDATE SKIP LOCKED")   # see SQLite note below
              .first
    return nil unless issue

    issue.update!(
      agent: agent,
      claim_state: "claimed",
      claimed_at: Time.current,
      claim_expires_at: Time.current + lease
    )
    issue
  end
end
```

**SQLite note**: `FOR UPDATE SKIP LOCKED` is a PostgreSQL idiom. On SQLite there
are no row locks and writes are serialised at the database level, so the safe
portable form is a **guarded conditional update** that lets the DB arbitrate:

```ruby
updated = where(id: issue.id, claim_state: "open")
            .update_all(
              agent_id: agent.id,
              claim_state: "claimed",
              claimed_at: Time.current,
              claim_expires_at: Time.current + lease
            )
# updated == 1  → this agent won the claim
# updated == 0  → someone else took it; loop to the next open issue
```

Build the claim around the guarded `update_all` returning the affected row count
as the source of truth. Wrap the select-then-guarded-update in a retry loop that
advances to the next open issue on a `0` result. This is portable across SQLite
now and Postgres later, and it is the part most worth checking against
Paperclip's real implementation.

### Lifecycle and release

- `claimed → in_progress` when the agent begins work (optional intermediate;
  keep if it earns its place, else collapse into `claimed`).
- `in_progress → done` on success; clear `claim_expires_at`.
- **Lease expiry / release**: a recurring sweeper finds issues whose
  `claim_expires_at < now` and state is `claimed`/`in_progress`, and returns them
  to `open` (clearing `agent_id`, `claimed_at`, `claim_expires_at`). An agent
  renews its lease by extending `claim_expires_at` on each heartbeat while it
  holds the issue — so a live agent keeps its claim and a dead one loses it.
- Tie release into heartbeat orphan recovery (Part 1): sweeping an orphaned agent
  also releases its claimed issues.

## Part 3 — Budget (optional, only if real spend is in play)

Paperclip enforces budget in the *same atomic step* as the claim. Add only when
Chorus is actually driving metered model spend; until then it is speculative
(defer per the simplicity rule). When needed:

- A budget lives on Agent or Role (decide then). The claim transaction
  decrements/checks remaining budget in the *same* guarded update, so a claim
  that would breach budget fails atomically rather than being caught after the
  fact.

## Goal ancestry (cheap, can land with this phase)

Paperclip carries full goal ancestry on every task so the agent sees the "why".
After the respine, an Issue already reaches its Goal via
`issue → project → goal → strategy`. Expose this as a read-path helper
(`Issue#goal_ancestry` returning project/goal/strategy) rather than a denormalised
column, unless query performance later demands materialising it. No schema change
needed; this is just a convenience method plus a spec.

## Workspace project history (parked from A2)

The A2 respine deliberately modelled only a Workspace's *current* active project
(`active_project_id`), not the list of projects that have occupied it over time.
That was the right call for the respine — history was a hypothetical then — but
the "durable, serial" design exists precisely so a workspace can be reused across
many projects, which means the audit trail of past occupants is a real
eventual need, not a speculative one. Capture it here so it isn't lost.

The design question is *how* to record history, and there are two shapes:

- **Occupancy event log** (preferred). A `chorus_workspace_occupancies` table:
  `workspace_id`, `project_id`, `started_at`, `ended_at` (nullable = current).
  Claiming a workspace for a project closes any open occupancy and opens a new
  one; `active_project_id` becomes a derived convenience (the project of the open
  occupancy) or a denormalised cache of it. This captures *when* each project
  held the workspace and naturally supports "what ran here before", overlap
  detection, and duration reporting. It also makes the serial invariant
  enforceable: at most one occupancy per workspace may have `ended_at IS NULL`
  (partial unique index).

- **Simple join with a flag** (lighter, less information). A
  `chorus_workspace_projects` join carrying an `active` boolean. Cheaper, but it
  loses timing and ordering, and the "one active" rule still needs a partial
  unique index. Only choose this if timing genuinely never matters — and given
  this feeds an agent-orchestration audit trail, it probably does.

Recommendation: the occupancy log. It subsumes `active_project_id` (which can
stay as a cache for query convenience) and gives the durable, reconcilable
history the architecture's audit posture wants. Keep the serial invariant in the
database (partial unique index on open occupancy), not just in model code.

This is independent of heartbeat and checkout and can land before, after, or
alongside them — it is parked here only to keep all deferred Chorus work in one
place. When it lands, update `chorus/CLAUDE.md` (the Workspace invariant section
currently says history is deferred) and the README in the same step.

## Done when

- Agents have heartbeat columns, a scheduler job, an event-trigger path, and
  coalescing that provably never double-enqueues.
- Issues have claim columns and a claim path whose race-safety rests on the
  guarded `update_all` row count, with a retry loop and a lease sweeper.
- Orphan recovery returns both stuck agents and their claimed issues to a
  workable state.
- Specs cover: two agents racing for one issue (exactly one wins), lease expiry
  releasing a claim, an agent renewing its lease, and a coalesced heartbeat not
  double-running.
- `bin/ci` green; migrations edited in place; no corrective migrations.

## Read before implementing

- Paperclip's task-checkout transaction and heartbeat scheduler
  (github.com/paperclipai/paperclip) — for the claim and coalescing subtleties.
  Lift semantics, not code (their stack is Node/React, ours is Rails/SQLite).
- Confirm the SQLite guarded-update approach against the dummy app's actual
  adapter config before committing to it.
