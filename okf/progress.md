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

- **`CnfsOkf::Config`** (`lib/cnfs_okf/config.rb`, required from `lib/cnfs_okf.rb`)
  — `CnfsSupport::Config` subclass. `owned_concept_policy` (default `:protect`),
  `listen_latency` (`0.5`), `listen_only` (`/\.md\z/`). `coerce_types
  owned_concept_policy: :string` + a `#owned_concept_policy` reader that
  `.to_sym`s normalizes the ENV-String and initializer-Symbol paths to one Symbol;
  `on_load` validates against `OWNED_CONCEPT_POLICIES` and raises
  `Anyway::Config::ValidationError` otherwise. Verified boots on all four paths
  (default / Symbol assign / ENV String / invalid → raise).
- **`CnfsOkf::Sync`** (`app/services/cnfs_okf/sync.rb`) — THE reconciliation entry
  point, `Sync.call(bundle:, paths: nil)`. Idempotent; create/update/destroy
  matrix; MD5 short-circuit reads the file once via memoized `raw_content`; policy
  branch per the plan table; returns a `Result` Struct; emits `cnfs_okf.sync.run`.
  Knows nothing about `listen`.
- **`Concept#diverged?`** — derived (`content_hash != MD5(file)`), no new column.
- **`FsConcept#without_persist`** seam + `frontmatter_changed?` honours
  `@suppress_persist`, so a disk→DB apply doesn't bounce back out to the file
  (spec asserts byte-for-byte no-write-back).
- **`FsBundle#sync_concepts`** now delegates to Sync; `ino_match?` retained as a
  guard (no args, computes both sets itself); `Bundle#create_concepts` also routes
  through Sync — one code path builds concepts. `cnfs_okf.bundle.sync` /
  `cnfs_okf.bundle.create` events collapsed into `cnfs_okf.sync.run`;
  `instrumentation_spec` updated (event name + `created`/`destroyed`/`skipped`
  payload keys).
- **`CnfsOkf::Listener`** (`lib/cnfs_okf/listener.rb`) — one process, N bundles,
  longest-prefix routing, `rescue` inside the `listen` callback. `listen` added as
  a gemspec runtime dep, required only from `listener.rb`.
- **Rake** `cnfs_okf:sync` / `cnfs_okf:listen` in the engine; dummy `Procfile.dev`
  gains a `listener:` line. Dummy initializer `config/initializers/cnfs_okf.rb`
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
- `create_concepts` dropped its own `cnfs_okf.bundle.create` event; Sync's
  `cnfs_okf.sync.run` covers the create.
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
# flip policy: CNFS_OKF_OWNED_CONCEPT_POLICY=quarantine, or uncomment the dummy initializer
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
