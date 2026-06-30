# Architecture — content storage for Chorus

**Status: design rationale, not yet built.** This records *why* content storage
is shaped the way it is, and the decision sequence for building it. Nothing here
is Phase A2 scope. The only part that binds today is the negative decision in
"Decide now" below.

## The question this answers

Several Chorus models carry narrative content: a Strategy has a statement, a Goal
a description, a Project a brief, an Issue a body. Where does that content live?

Two tempting answers are both wrong:

- **A `body:text` column on each table.** Makes that column the source of truth
  for content. When OKF (or any document store) later wants to own documents,
  there are now two homes for the same content and you are forced into a
  migration or a two-master sync — exactly the durability/identity problem OKF
  exists to solve, recreated badly inside Chorus with no front-matter identity
  and no reconciliation. The column is not a neutral fallback; it is a competing
  storage decision baked into the schema.
- **Couple Chorus to OKF.** Chorus would reference `Okf::` constants and depend
  on OKF's API shape, dissolving the OKF-naive invariant that is Chorus's
  cleanest architectural guarantee (it is currently grep-enforceable: no `okf`
  in `chorus/`). Pre-v1 OKF's API will move, version-coupling two engines that
  were deliberately kept independent.

## The shape we chose: Chorus owns a seam, not storage

Chorus owns a **content interface** (a Chorus-defined abstraction: "this record
has narrative content I can read and write, addressed by an identifier, through a
backend Chorus does not implement") plus a **naive default backend** so a bare
install runs standalone. Real backends are pluggable and live in an optional
adapter gem. This is the ActiveStorage/ActiveJob pattern: the framework owns the
interface and a humble default; production backends are swappable and live
elsewhere.

### Three components, three homes

1. **The seam — inside Chorus.** A Chorus-defined interface plus the minimum
   default backend (content in a `chorus_documents` row or a configured
   directory — just enough to store and render). Has **zero** knowledge of OKF or
   any specific backend; stays grep-clean. This is what makes "Chorus works out
   of the box" literally true with no extra dependencies.

2. **`chorus-storage` — an optional adapter gem.** Installed by a host that wants
   a real backend. Provides multiple adapters (directory-based production-grade,
   ActiveStorage, OKF, …) registered against Chorus's interface and selected by
   configuration. The OKF adapter is the only place `Okf::` constants appear, and
   it is loaded lazily (`require "okf"` only when the OKF backend is selected) so
   installs using other backends never load OKF.

3. **The host app** chooses: nothing (Chorus's naive default), or add
   `chorus-storage` and configure a backend.

### Why the seam stays in Chorus rather than in `chorus-storage`

Two invariants must both hold: grep-`okf`-returns-nothing in `chorus/`, **and**
Chorus works out of the box. If `chorus-storage` were a hard dependency of
Chorus, every install would carry adapter code (including OKF-aware code) it
mostly will not use, and "out of the box" would depend on a second gem. Keeping
the interface and naive default *inside* Chorus satisfies both claims with no
asterisk. `chorus-storage` is therefore an **optional add-on**, not a dependency.

### The two directory backends are allowed to coexist

Chorus's internal default may be a directory/table backend, and `chorus-storage`
also offers a directory adapter. They serve different purposes and that is fine:
the internal one is the absolute-minimum "survive standalone" backend; the
`chorus-storage` one is the configurable, production-grade version (custom paths,
possibly front-matter). Same idea, different jobs.

## The discipline that keeps this honest

The content interface MUST be designed from **Chorus's own needs** ("a Strategy
has narrative content I can read and write"), then each adapter conforms to it —
never the reverse. If the interface is designed by looking at OKF's API, OKF's
assumptions leak into the "neutral" seam and the decoupling becomes cosmetic.
This is the single most important rule here.

## Switching backends is a swap, not a sync

Content has exactly one home at a time: the active backend. Moving from the naive
default to OKF is a one-time migration (a rake task `chorus-storage` can provide),
not an ongoing sync. There is never a `body` column competing with a backend for
truth, so the two-master problem never arises.

## Decision sequence (respecting build-only-when-needed)

1. **Now (free, binding):** domain tables stay **content-column-free**. No
   `body`/`content`/`markdown` column on Strategy, Goal, Project, Issue, or any
   domain model. This keeps every option open and costs nothing. Recorded as an
   invariant in `chorus/CLAUDE.md`.
2. **When the first content feature lands:** design the Chorus content seam from
   Chorus's needs, and build the naive default backend. Defer until a real
   feature needs to store and render a document — that feature reveals what
   operations the interface actually needs (read/write only? versioning?
   listing?), which designing earlier would only guess at.
3. **When the first host needs a real backend:** build `chorus-storage` with the
   directory/ActiveStorage adapters; add the OKF adapter when durable,
   reconcilable, front-matter-identity storage is wanted. OKF's API will be more
   settled by then, making the adapter easier to write correctly.

## Relationship to Artifacts

Distinct concern, do not conflate. An Artifact (git repo, OKF bundle reference)
is an external resource a Workspace points at by locator. Content storage is
where a domain record's *own* narrative text lives. A Strategy's statement is
content (seam); the Solana repo it relates to is an Artifact (locator). They may
both eventually touch OKF, but through different mechanisms and for different
reasons.
