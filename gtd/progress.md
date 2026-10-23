# gtd — progress

Append-only completion log. One entry per plan.

---

## PLAN 012 — GTD implementation (the end-to-end spike)

Plan: `../../doc/plans/012-gtd-implementation.md`. Governing ADRs 0005
(presentation/domain/storage separation + the content seam) and 0006 (the
column-assertion seam). Scope: the payoff — a single `Appwork::Gtd::Action` that is at once
an OKF concept owner, a Kanban placement subject, and an assertion honorer,
proving the three-layer separation end to end. This gem is the **ADR 0005
composition root**: it depends on BOTH `cnfs_okf` and `partitia-ui`, and `Appwork::Gtd::Action`
is the only file in the workspace where the two flanking layers co-occur.

**Green count:** rspec **15 examples / 0 failures** (9 model + 6 request). rubocop
51 files, 0 offenses. All four seam audits clean (audit [1]'s only hit is the
documented `card.rb` doc-comment, as in 010/011).

### What shipped

- **Tier 1 — the three hats (composition root).** `Appwork::Gtd::Action`
  (`app/models/gtd/action.rb`) wears all three, unit-tested in isolation:
  - **Content owner (010 / ADR 0005):** `include Appwork::Okf::Consumer`,
    `has_one_okf :concept`; `delegate :title, to: :concept`,
    `body = concept&.content`, `update_content(body:)` = stage + `save!` — copied
    verbatim from `Note`. No `Partitia::Ui` constant in the read/write path; the arrow
    stays partitia-ui → interface.
  - **Placement subject (011 / ADR 0005):** `has_many :placements, as: :subject,
    class_name: "Partitia::Ui::Placement", dependent: :destroy` — verbatim from `Note`.
  - **Assertion honorer (0006), GUARDED:** `satisfy_assertion(attribute:, value:)`
    switches `case attribute; when :status then update!(status: value); else nil`.
    This is the ONE place 012 is deliberately stricter than the `Note` reference,
    which does a naive `update!(attribute => value)`. `Appwork::Gtd::Action` has real domain
    semantics, so an unexpected asserted attribute is a **safe no-op**, never a
    blind column write.
  `Appwork::Gtd::Project` is a lighter OKF consumer (owns a concept, `has_many :actions`);
  `Appwork::Gtd::Context` is a plain grouping label (not concept-owning, not a placement
  subject — the context board is a pure view). Three migrations (`appwork_gtd_contexts`,
  `appwork_gtd_projects`, `appwork_gtd_actions`; nullable FKs on actions), auto-discovered via
  `Partitia::Support.migrations_paths` alongside okf's and partitia-ui's sets.
- **Tier 2 — the OKF content bundle on disk.** `spec/fixtures/bundles/gtd/`
  ships 6 action + 3 project markdown files (frontmatter title + body). The seed
  copies fixtures → a gitignored working dir, `Appwork::Okf::Bundle.create!(path:)`
  fires Sync to build concepts, and each `Appwork::Gtd::Action`/`Project` **claims** its
  concept (`update!(concept: bundle.concepts.find_by!(path:))`) — the okf
  Strategy↔concept idiom. `action.title` returns the frontmatter title from disk,
  verified before boards were built.
- **Tier 3 — three boards on the SAME actions (the headline asymmetry).**
  `spec/dummy/db/seeds.rb`, all on Plan 011's `Board`/`Column`/`Placement`:
  - **Workflow** — columns `Inbox/Next/Waiting/Done`, each carrying
    `assertion_attribute: "status", assertion_value: <status>`. The ONLY asserting
    board.
  - **Context** (`@home/@work/@calls`) and **Project** (one column per project) —
    plain columns, no assertion. Pure views (ADR 0005).
  Each of the 6 actions gets **three placements** (one per board), independently
  positioned — 18 placements total, never a shared row. Seed data spans all four
  statuses, all three contexts, all three projects, so every board is non-trivial.
- **Tier 4 — the GTD dummy renders the boards.** `partitia-ui` mounted so
  `partitia_ui.reposition_placements_path` resolves; `resources :boards, only:
  %i[index show]`; `BoardsController#show` builds
  `Partitia::Ui::Components::Kanban::Board.new(board:, reposition_url:)` (URL passed in —
  seam rule). The dummy's Tailwind entry was swapped to the `source_paths`-driven
  `application.css.erb` + a `tailwindcss:render_entry` rake task (mirroring
  partitia-ui's dummy, minus the Lookbook previews `@source`), so the Kanban
  components authored in partitia-ui compile styled here. The stock
  `eagerLoadControllersFrom("controllers")` picks up the engine's
  `partitia-ui--sortable` controller via partitia-ui's importmap initializer — zero JS
  wiring. Verified live: `GET /boards/1` → 200, renders the seeded card titles
  from disk, all four workflow columns, the `partitia-ui--sortable` binding, and the
  `/partitia/ui/placements/reposition` endpoint.
- **Tier 5 — the end-to-end proof (request specs).** `spec/requests/
  appwork_gtd_boards_spec.rb` replays the exact sortable PATCH
  (`{ ids:, list_id:, new_position: }`) and asserts the asymmetry:
  - **Workflow** move `Next → Done` → placement moves AND `action.status` becomes
    `"done"` (the 0006 relay).
  - **Context** move `@work → @home` → placement moves and **nothing else**;
    `status` and `context` untouched, `satisfy_assertion` never received.
  - **Reorder** within a column → `position` only, no domain, no relay.
  - **Independence** → moving the Workflow placement leaves the same action's
    Context placement put (three rows, not one).
  - **Rendering** → `GET /boards/:id` shows a card title read from the action's
    concept on disk (partitia-ui binds only `title`, never OKF).

### Decisions worth flagging

- **`satisfy_assertion` is guarded, per the plan.** Unlike `Note`, `Appwork::Gtd::Action`
  honors only `:status`; anything else is a no-op. Since the context/project
  boards are plain (relay nothing), nothing else should ever reach the method —
  the guard is defense-in-depth for the domain's real semantics, and its no-op
  branch is unit-tested (`saved_changes?` stays false on an unexpected attribute).
- **Context is deliberately NOT assertion-driven** (resolves the old fork). The
  context board is a pure view; only the workflow board asserts, because its
  columns literally ARE the `status` enum. Making context assertive later is a
  one-line column-config change (`assertion_attribute: "context"`) plus a
  `when :context` branch — explicitly out of v0.1 scope (plan design note).
- **Every action is project-backed** (added an `Errands` project for standalone
  life-admin actions) so each action gets a placement on all three boards — the
  "same action → three placements" property holds uniformly.
- **Two stock-generator fixes** the fresh dummy needed (same class as 010's):
  `rails_helper` required the plain-app `../config/environment` → now
  `dummy/config/environment`; `database.yml`'s `migrations_paths` moved into
  `default:` so the **test** env inherits all three engines' migrations. `.rubocop`
  gained `TargetRubyVersion: 4.0` + `Exclude: spec/dummy/db/schema.rb`.
- **The `muted` token doesn't exist** in partitia-ui's `tokens.css` (only
  surface/fg/edge/primary); the boards index uses `text-fg opacity-60` instead of
  a `text-muted` that would compile to nothing.

### Seam audits — the layering the spike proves

```
grep -rn "Appwork::Okf\|Concept" gems/ui/app/               # → only card.rb's doc-comment (the rule it honors)
grep -rn "Gtd\b" gems/ui/app/                          # → nothing (partitia-ui stays domain-free)
grep -rn "Partitia::Ui::Placement\|Partitia::Ui::Board" gems/okf/  # → nothing (okf stays presentation-blind)
# Files naming BOTH Appwork::Okf and Partitia::Ui in gems/gtd/app/:
#   → gems/gtd/app/models/gtd/action.rb   (the composition root, and only it)
```

### How to run it

```
cd gems/gtd && unset RUBYLIB && bundle exec rspec && bin/rubocop   # 15 examples, 51 files clean
cd gems/gtd/spec/dummy && unset RUBYLIB && bin/rails db:reset      # seeds 3 boards over 6 actions
cd gems/gtd/spec/dummy && unset RUBYLIB && bin/dev                 # bin/dev, NOT bin/rails s (stale Tailwind)
#   /boards                → three boards (Workflow asserts; Context/Project pure views)
#   /boards/1 (Workflow)   → drag Next → Done changes Action.status
#   /boards/2 (Context)    → drag @work → @home changes NOTHING (view only)
#   /boards/3 (Project)    → view only; titles/bodies from disk
```

### Not built (deferred per plan)

Full GTD five phases (weekly review, someday/maybe, reference filing);
capture-creates-a-new-concept-file (inbox → new markdown via OKF's write path +
`has_one_okf` build); making the context board assert `context` (one-line change);
real-time multi-viewer board sync (the reposition endpoint is the attach point);
a JS-driver system spec exercising a real browser drag (request specs replaying
the sortable PATCH are the durable proof, matching 011).
