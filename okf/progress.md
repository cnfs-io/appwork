# OKF progress log

## v3 models, STI, consumer concern, dummy Chorus models (PLAN-v3-models)

**What shipped**

- Engine migration `db/migrate/20260628170200_create_okf_v3_models.rb` —
  `okf_bundles` (`sti_type`, self-ref `bundle_id` parent, `path`, polymorphic
  `owner`) and `okf_concepts` (`bundle_id`, `path`, `ino`, `content_hash`, six
  SPEC frontmatter columns `type`/`title`/`description`/`resource`/`tags`(json,
  `[]`)/`timestamp`, `custom_frontmatter` text, polymorphic `owner`).
  `to_table: :okf_bundles` on both `okf_`-prefixed FKs.
- Dummy migration `spec/dummy/db/migrate/20260628170201_create_chorus_models.rb`
  — `organizations`, `strategies`, `goals`, `projects`, `issues` with the
  domain `belongs_to` chain via plain FKs.
- OKF models: `Okf::Bundle` (STI on `sti_type`, parent/children self-ref,
  `concepts`, polymorphic owner, recursive `pathname`), `Okf::RootBundle <
  Bundle` (own file for Zeitwerk), `Okf::Concept` (`inheritance_column = nil`,
  `serialize :custom_frontmatter, coder: YAML, type: Hash`, `pathname`).
- `Okf::Consumer` concern (`app/models/concerns/okf/consumer.rb`) with
  `owns_many_okf` / `owns_one_okf` — class inference + `class_name:` override.
- Dummy Chorus models: `Organization` (owns `root_bundle` + `concept`),
  `Strategy→Goal→Project→Issue` (each owns a concept, delegates `title`/
  `description` by hand; `Strategy` carries the worked `priority`
  custom-frontmatter accessor).
- ADR `doc/adr/0001-two-model-flat-projection.md`.

Tier 5 console snippet runs end to end (root/nested/concept pathnames, owner
identity, delegated title, custom-frontmatter round-trip, STI subclass
resolution, `Concept#type` as a plain attribute).

**Decisions worth flagging**

- `bin/rails app:db:migrate` installs **and** runs both the engine migration and
  the dummy's own migration in a single pass — no separate dummy `db:migrate`
  needed. Both timestamps migrated together.
- `serialize ..., type: Hash` is supported on Rails 8.1; no fallback to a
  `"--- {}\n"` DB default was needed. Custom bag reads back as a real Hash.
- Pre-existing `lib/okf.rb` `self.bundles_root` was already present (uncommitted)
  and left untouched — storage-root config is out of this plan's scope.
- Stale `spec/dummy/storage/development.sqlite3` clobbered before migrating, per
  plan.

**Scope held** — no references join/macros, no validations/specs/factories, no
write path or disk I/O, no frontmatter DSL.

**How to run / explore**

```
bin/rails app:db:migrate            # installs + runs engine and dummy migrations
bin/rails console                   # play with Organization / Okf::Bundle / Okf::Concept
```

## Content sync, configurable ownership policy, and the FS listener (PLAN-sync-and-listener)

**What shipped** — full suite green: **23 examples, 0 failures**; RuboCop clean.

- **`Appwork::Okf::Config`** (`lib/appwork/okf/config.rb`, required from `lib/appwork/okf.rb`)
  — `Partitia::Support::Config` subclass. `owned_concept_policy` (default `:protect`),
  `listen_latency` (`0.5`), `listen_only` (`/\.md\z/`). `coerce_types
  owned_concept_policy: :string` + a `#owned_concept_policy` reader that
  `.to_sym`s normalizes the ENV-String and initializer-Symbol paths to one Symbol;
  `on_load` validates against `OWNED_CONCEPT_POLICIES` and raises
  `Anyway::Config::ValidationError` otherwise. Verified boots on all four paths
  (default / Symbol assign / ENV String / invalid → raise).
- **`Appwork::Okf::Sync`** (`app/services/cnfs_okf/sync.rb`) — THE reconciliation entry
  point, `Sync.call(bundle:, paths: nil)`. Idempotent; create/update/destroy
  matrix; MD5 short-circuit reads the file once via memoized `raw_content`; policy
  branch per the plan table; returns a `Result` Struct; emits `partitia_appwork.sync.run`.
  Knows nothing about `listen`.
- **`Concept#diverged?`** — derived (`content_hash != MD5(file)`), no new column.
- **`FsConcept#without_persist`** seam + `frontmatter_changed?` honours
  `@suppress_persist`, so a disk→DB apply doesn't bounce back out to the file
  (spec asserts byte-for-byte no-write-back).
- **`FsBundle#sync_concepts`** now delegates to Sync; `ino_match?` retained as a
  guard (no args, computes both sets itself); `Bundle#create_concepts` also routes
  through Sync — one code path builds concepts. `partitia_appwork.bundle.sync` /
  `partitia_appwork.bundle.create` events collapsed into `partitia_appwork.sync.run`;
  `instrumentation_spec` updated (event name + `created`/`destroyed`/`skipped`
  payload keys).
- **`Appwork::Okf::Listener`** (`lib/cnfs_okf/listener.rb`) — one process, N bundles,
  longest-prefix routing, `rescue` inside the `listen` callback. `listen` added as
  a gemspec runtime dep, required only from `listener.rb`.
- **Rake** `cnfs_okf:sync` / `cnfs_okf:listen` in the engine; dummy `Procfile.dev`
  gains a `listener:` line. Dummy initializer `config/initializers/appwork_okf.rb`
  ships the `:quarantine` override commented out (boots on default `:protect`).

**Decisions worth flagging**

- **Sync loads FRESH records** (`@bundle.concepts.reload`). A Bundle handed in
  carries a cached `concepts` association whose members memoized `@raw_content` at
  create time — without the reload every changed file read as unchanged (caught in
  spec). `reload` keeps `inverse_of`, so `concept.bundle` stays wired (no N+1 in
  `#pathname`). This is the plan's Tier 3 "work from freshly-loaded records" note,
  made load-bearing.
- **Listener canonicalizes bundle roots to `realpath`** (guarded for
  non-existent test-double paths). `listen` emits symlink-resolved paths (macOS
  `/tmp` → `/private/tmp`); without canonicalizing the roots the same way,
  longest-prefix routing never matched and events were silently dropped. This was
  the one thing the Neovim end-to-end test caught that unit tests could not.
- `create_concepts` dropped its own `partitia_appwork.bundle.create` event; Sync's
  `partitia_appwork.sync.run` covers the create.
- One pre-existing RuboCop whitespace offense in the untouched `view_port.rb` was
  autocorrected (cosmetic only) to keep the tree clean; ViewPort logic untouched.

**Verified (Tier 7 console)** — edit→sync→title follows; idempotent second call
all-unchanged; add-file picked up; **Neovim temp-file+rename** reconciles to the
new content both via a direct `Sync.call` AND through a live `Listen` thread;
`:quarantine` leaves an owned concept's DB attributes untouched and `diverged?`
true.

**Scope held** — no gates, no provenance/actor tracking, no event/transition-log
table, no snapshots, no polling/multi-host triggers, no `Bundle#listen`, no new
column for quarantine state. `ViewPort` untouched.

**How to run / explore**

```
bundle exec rspec                          # 23 examples
BUNDLE=<id> bin/rails cnfs_okf:sync         # reconcile one (or all) bundles
bin/rails cnfs_okf:listen                   # watch + sync (dedicated process)
# flip policy: APPWORK_OKF_OWNED_CONCEPT_POLICY=quarantine, or uncomment the dummy initializer
```

## Harden listener/sync coverage, single-bundle ergonomics, dummy trim, README

**What shipped** (44 examples, 0 failures; rubocop clean)

- **Model-layer specs** the sync/listener refactor lacked: `spec/models/cnfs_okf/
  bundle_spec.rb` (`#mv` success + same-fs `ino_match?` short-circuit that skips
  Sync + dest-exists/parent-missing failure branches + `concept_paths`/`tree`/
  `ls`), `view_port_spec.rb` (`#concepts` root vs `LIKE`-scoped, `#tree`,
  `path_must_be_directory`), `concept_spec.rb` (`#diverged?` match/changed/
  missing, frontmatter known-vs-`custom_frontmatter` mapping and the
  `changed`-guard). Extended `listener_spec.rb` with `#canonical` (symlink→
  realpath, non-existent pass-through).
- **`Listener` accepts a single bundle.** `initialize` now does
  `Array(bundles).index_by { ... }`, so `Listener.run(bundles: Bundle.first)`
  works alongside `Bundle.all`; `Array(nil)`/`Array([])` still trip the
  "no bundles to watch" guard. `cnfs_okf:listen` gained a `BUNDLE=<id>` selector
  mirroring `cnfs_okf:sync`.
- **Dummy domain trimmed** to `Account → Strategy → Goal`. `Organization`
  renamed to `Account` (still the owner stand-in + Consumer-DSL example);
  `Project`/`Issue` models and tables removed; `Strategy belongs_to :account`;
  `Goal` dropped `has_many :projects`. The `create_chorus_models` migration was
  edited in place (pre-v1) and `spec/dummy/db/schema.rb` regenerated; `sync_spec`
  owner stand-ins are now `Account`.
- **README rewritten** for the consumer developer (install → quick start →
  common tasks → config table → dev), read from source per the readme-authoring
  skill. Gemspec `summary`/`description`/`homepage` filled and the invalid
  `source_code_uri`/`changelog_uri` TODO metadata removed so `gem build` passes.

**Decisions worth flagging**

- The original review premise — `Listener` calling a missing `Bundle#index_by` —
  was a misread: `index_by` is `Enumerable#index_by` on the collection. No bug;
  the refactor was already green. This pass hardened coverage rather than fixing
  a defect.
- Regenerating `schema.rb` after an in-place migration edit requires moving the
  stale `schema.rb` aside first — `db:migrate` on a fresh DB loads the existing
  `schema.rb` (versions already recorded) instead of running migrations.

**Scope held** — no gem-model/gem-migration changes; no `spec/support` or
`rails_helper` edits; no factories; listener routing doctrine unchanged.

**How to run**

```
(cd spec/dummy && bin/rails db:drop db:create db:migrate && bin/rails db:test:prepare)
bundle exec rspec            # 44 examples
bundle exec rubocop app spec lib
```

---

## Dummy proving ground: owned-concept policy wired (PLAN-cnfs-support-walker-and-cleanup, Part B)

**What shipped**

- `Account` fixed — was `has_one_okf :bundle` + `has_one_okf :concept` (neither
  designed). Now `has_many_okf :bundles`; Account owns many bundles, concept
  ownership belongs to Strategy.
- Committed fixtures `spec/fixtures/bundles/` (acme + playbook trees): nested
  dirs, a file with a custom frontmatter key (`priority`), and a
  frontmatter-less `README.md` (miss path).
- `spec/dummy/db/seeds.rb` — copies fixtures → gitignored `storage/bundles`,
  creates an Account + one Bundle per dir (`after_create` → Sync builds
  concepts), then a Strategy CLAIMS an existing concept (activating the
  owned_concept_policy branch). Destructive + idempotent at the working-dir
  level (fresh Account rows each run, by design).
- `spec/services/cnfs_okf/owned_concept_policy_spec.rb` — the full policy matrix
  through a REAL Strategy owner + the write-path-under-ownership cases: a UI
  `content=` edit writes disk, restamps the hash, and `Sync.call` then reports
  **unchanged, not updated** (the feedback-loop short-circuit); a `priority=`
  edit round-trips custom frontmatter to YAML with the body untouched.
- Tailwind entry moved to `application.css.erb` driven by
  `Partitia::Support.source_paths` (Part A). See the Tailwind ERB note below.

**Decisions worth flagging**

- **tailwindcss-rails 4.6.0 does NOT run ERB over its entry file** (the plan
  assumed it did) — it hardcodes `application.css` and hands it straight to the
  CLI. Added `spec/dummy/lib/tasks/tailwind_erb.rake` (`tailwindcss:render_entry`)
  that renders `application.css.erb` → `application.css` before build/watch, and
  gitignored the rendered `application.css` (absolute, machine-specific paths).
  Kept dummy-local by decision (UI gem is on hold); promote to partitia-ui when it
  lands.
- `db:clobber` in the plan is not a real task here; used
  `db:drop db:create db:migrate`.
- Console gate confirmed: `Sync.call` after a UI edit → `unchanged=3` (acme has
  3 concepts), NOT `updated=1`.

**How to run**

```
bundle exec rspec            # 66 examples (10 new in owned_concept_policy_spec)
(cd spec/dummy && bin/rails db:drop db:create db:migrate db:seed && bin/rails tailwindcss:build)
bin/rubocop
```

---

## `okf_frontmatter` accessor macro (006-frontmatter-macro)

**What shipped** — full suite green: **73 examples, 0 failures** (+7 from 66);
RuboCop clean (68 files, 0 offenses).

- **`Appwork::Okf::Consumer.okf_frontmatter(*names)`** — class macro alongside
  `has_one_okf` / `has_many_okf`. For each name it defines a delegating
  read/write accessor pair over the owned `:concept`'s serialized
  `custom_frontmatter` Hash (string keys). Extracts, verbatim, the pair
  `Strategy` carried by hand.
- **`spec/dummy/app/models/strategy.rb`** — hand-written `priority` /
  `priority=` replaced with `okf_frontmatter :priority`. The
  `delegate :title, :description, to: :concept` line stays (standard Concept
  columns, not custom frontmatter).
- **`spec/models/cnfs_okf/consumer_frontmatter_spec.rb`** — 7 examples pinning
  read (value / missing-key nil / concept-less nil) and write (store / merge
  without clobber / persist-to-disk round-trip / concept-less raise).

**Decisions worth flagging**

- **The read/write nil-safety asymmetry is the contract, and is pinned
  explicitly.** Read is `&.`-guarded — a concept-less consumer reads `nil`.
  Write is NOT guarded — a concept-less consumer *raises* `NoMethodError`
  (asserted directly). A consumer that declares `okf_frontmatter` is expected to
  own a concept (`has_one_okf :concept`); absence is a consumer bug, not a case
  to defend. The write assertion exists so a later session doesn't "fix" the
  raise into silent nil-handling and quietly break the contract.
- **Concept-less fixture is built the honest way** — a bare
  `account.strategies.create!` that claims no concept, NOT the seed path (which
  has a Strategy claim an existing concept). Auto-claiming would make the
  nil/raise branches untestable.
- **`Appwork::Okf::Concept` untouched.** The macro is entirely consumer-side; the
  existing OKF/Concept specs stayed green, confirming Concept behavior is
  unchanged.

**Scope held** — accessor pair only. No `okf_projected_fields`, no
`column_names` introspection, no `partitia_appwork.sync.run` subscriber, no
precedence/write-loop guard, no migration change, no notifications/callbacks.

**On the horizon (deferred — recorded, not built).** Queryable projection of a
declared custom-frontmatter key into a first-class AR column
(`Strategy.where(priority: ...)`) is **explicitly deferred** — speculative until
a consumer writes a query that needs it, and it carries all the complexity
(subscriber, disk-wins vs. local-wins precedence, write-loop guard, per-tick
walk over owned concepts) while the macro carries none. The macro leaves the
door fully open: projection can land later without changing the accessor surface
consumers already use. Three questions to settle *then*, none now — **trigger**
(subscribe to `partitia_appwork.sync.run` and follow `concept.owner` back, vs. a
macro-wired per-concept reload callback), **precedence** (recommend disk-wins;
a runtime-authoritative value shouldn't be modeled as a projected column), and
**write-loop/cost** (project without a concept persist; save the owner only on
an actual change). See `doc/plans/006-frontmatter-macro.md` "On the horizon".

**How to run**

```
bundle exec rspec            # 73 examples
bin/rubocop
```

## ViewPort materializes its directory (007-view-port-materialize)

**What shipped** — a `ViewPort` can now create its own directory on disk, so a
consumer (e.g. a `Appwork::Chorus::Workspace`'s `has_one_okf :view_port` into a
host-seeded bundle) can point at a `plans/` directory an agent is *about to*
write into, rather than one that must already exist. **82 examples, 0 failures;
RuboCop clean.**

- **`ViewPort#materialize`** (`attr_accessor`, not a column — a per-instantiation
  instruction, not persisted state) + `before_validation :materialize_path,
  prepend: true, if: -> { materialize && path.present? }`. `prepend: true` is
  load-bearing: FsNode's `before_validation :ident` reads `stat` to set `ino`; the
  directory must exist before that runs or `ino` stays nil and the record fails
  validation anyway. Same precedent as `Bundle`'s `prepend: true` on `expand_path`.
  Uses `mkpath` (not `mkdir`) so intermediates are created in one call.
- **`ViewPort#materialize!`** — public `pathname.mkpath`, for console use; the
  attribute is the supported path since it fires in the correct order.
- **Clearer missing-directory error** — `path_must_exist_as_directory` names the
  fix (`pass \`materialize: true\` to create it`) instead of leaving the caller to
  puzzle over FsNode's `ino can't be blank`. FsNode's `path_must_exist` still fires
  alongside it; a duplicate error on `:path` is acceptable, a confusing one isn't.
- **Bundle containment** — `path_must_be_within_bundle` (lexical `cleanpath`,
  runs regardless of `materialize`) rejects a `path` escaping the bundle root.
  Its predicate `within_bundle?` **also guards `materialize_path`**, because
  `materialize_path` is a `before_validation` and runs *before* the containment
  validation could reject the record — so `../outside` with `materialize: true`
  creates nothing on disk. Symlink containment is deferred (lexical check only).
- **Untouched, deliberately** — `path_must_be_directory` stays exactly as
  written (its `return unless pathname.exist?` guard is correct; existence is
  FsNode's job). `FsNode`, `Bundle`, `Concept`, `Sync` unchanged. `Bundle#ls`
  still builds a transient unsaved viewport (no validations, no disk) — specced.

**Two spec expectations in the plan's wishlist were inconsistent with code the
plan said to leave untouched; specs assert the real behavior:**
- *file at the path with `materialize: true`* — the plan predicted `mkpath`
  raising `Errno::EEXIST`, but `materialize_path`'s own `unless pathname.exist?`
  guard (plan §1) *skips* `mkpath` for an existing file. The file is rejected by
  the directory validation instead (`RecordInvalid, /is not a directory/`) and
  left untouched — same safety, different mechanism.
- *`path: ""` (bundle root)* — FsNode's untouched `validates :path, presence:
  true` rejects `""` as blank, so a root viewport is never *fully* valid. §5's
  point is containment: the spec asserts the escape check does **not** fire on
  `""`, not full validity.

**Unblocks** `chorus/doc/plans/011-work-order-domain-reshape.md` §6.

**How to run**

```
bundle exec rspec            # 82 examples
bin/rubocop
```
