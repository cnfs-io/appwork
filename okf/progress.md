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
