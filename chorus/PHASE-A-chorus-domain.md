# Phase A — Chorus Domain — SUPERSEDED (do not use)

> **This plan is obsolete. Do not read it as a reference for current Chorus.**

It described the original six-model spine
(`Organization → Workspace → Project → Issue`, with Organization reaching
Projects *through* Workspace) and an integration model in which OKF concerns were
to be mixed directly into Chorus models. **Both have been superseded.**

Current sources of truth:

- **Domain spine (current):** `PHASE-A2-domain-respine.md` — the nine-model
  intent spine `Organization → Strategy → Goal → Project → Issue`, with Workspace
  as a durable, serial execution surface and Artifact first-class.
- **What actually shipped:** `progress.md` (Phase A and Phase A2 entries).
- **Engine invariants (current):** `CLAUDE.md`, including the OKF-naive boundary.
- **OKF integration approach (current):** Chorus stays OKF-naive. OKF is never
  mixed into Chorus models. Content storage goes through a Chorus-owned seam with
  an optional `chorus-storage` adapter gem — see `ARCHITECTURE-content-storage.md`.
- **Deferred work:** `PHASE-B-heartbeat-and-checkout.md`.

This stub is kept only so references to the old filename resolve to a redirect
rather than stale content. It can be deleted.
