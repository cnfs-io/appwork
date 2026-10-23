# Chorus

Chorus is a mountable Rails engine that provides the **coordination substrate**
for human/AI participant work: a durable `Workspace` execution surface, an
`Artifact` store, `Agent` participants, a skill catalog, and the
`Appwork::Chorus::Workable` contract a host domain gem includes to make its own models
occupiable. Narrative content is backed by OKF (`cnfs_okf`) concepts through a
one-directional dependency: Chorus consumes OKF; OKF never knows Chorus.

Chorus does **not** own an org-chart domain. The intent spine
(strategy → goal → project → issue) and `Role` live in host gems (e.g.
`micro_manager`; IAM provides `Role`). A host becomes occupiable by depending on
Chorus and including `Appwork::Chorus::Workable`; Chorus is **host-agnostic** — it never
names or knows a host.

Chorus holds **no `Organization` model**: under `partitia-tenanted` there is one
database per account, and that database *is* one organization. `Workspace` and
`Agent` are top-level roots, scoped by the database rather than by an owning
column.

## Domain

The **execution surface** is a durable, serial `Workspace`: it occupies exactly
one polymorphic *workable* at a time (retaining nothing else about occupancy
history) and holds `Artifact`s.

```
Workspace    0──1  <workable>   (workable_id/workable_type; polymorphic, nullable, nullify)
Workspace    1───* Artifact     (destroy)
```

A host domain model becomes occupiable by including `Appwork::Chorus::Workable`, which
supplies the polymorphic inverse `has_one :workspace, as: :workable`. The concern
is **occupiability only** — status and host-domain semantics are not Chorus's.

An `Artifact` is first-class and type-open: a workspace holds many artifacts of
different `kind`s (e.g. `git_repo`, `okf_bundle`), each with a free-form
`locator`. Chorus blesses no artifact type. An `Agent` carries no direct
`workspace` link — agent↔workspace is discovered host-side.

Chorus also ships a **skill catalog** (`CatalogSkill`, `Curation`, `Taxonomy`,
`SkillCategorization`) and STI **`Source`** / **`ExternalAccount`** models (see
below). All tables are `chorus_`-prefixed; all models live under `Appwork::Chorus::` (the
engine uses `isolate_namespace Appwork::Chorus`). `kind` is a deliberately free string —
the host app owns those vocabularies.

> **Note:** the scaffold controllers/views (CRUD UI) were retired (a Phlex/Partitia::Ui
> UI will return later), so the sections below on theming and i18n describe that
> future UI layer, not code currently shipped.

## Installation

Add to your application's Gemfile:

```ruby
gem "chorus"
```

Mount it and install/run the migrations:

```ruby
# config/routes.rb
mount Appwork::Chorus::Engine => "/chorus"
```

```bash
$ bin/rails db:migrate   # the engine's migrations are picked up automatically
$ bin/rails db:seed      # optional (demo seeds are minimal today)
```

## Theming — semantic color tokens (host re-skins, no view forks)

Chorus ships **neutral**. Its views reference only **semantic color utilities** —
`bg-primary`, `text-text`, `border-border`, `bg-danger`, etc. — never literal
palette classes like `bg-blue-600`. These utilities are generated from a small set
of CSS custom properties declared in a Tailwind v4 `@theme` block at
`app/assets/stylesheets/chorus/tokens.css`:

```
--color-primary / --color-primary-contrast
--color-surface / --color-surface-muted
--color-border
--color-text    / --color-text-muted
--color-danger  / --color-danger-contrast
```

**Host override contract.** An enclosing app re-skins the entire Chorus UI by
redefining those same variables on `:root` in its own stylesheet, loaded after
Chorus's. Because every utility resolves `var(--color-*)` at runtime, the new
values cascade through every Chorus view with **zero view edits**:

```css
/* host app stylesheet, loaded after Chorus */
@import "tailwindcss";
@import ".../chorus/tokens.css";   /* registers the utilities + neutral defaults */

:root {
  --color-primary: oklch(0.48 0.085 192);  /* your brand */
  /* ...redefine the rest... */
}
```

The dummy app (`spec/dummy`) is the worked reference: its Tailwind entrypoint
(`app/assets/tailwind/application.css`) imports the engine tokens and overrides
them to a teal + warm-slate palette. Delete that override block and the UI falls
back to the engine's neutral grey.

## Internationalization

Every user-facing string routes through `t()` / Rails' model & attribute i18n
conventions. The engine ships only `config/locales/en.yml`. The host supplies any
additional locales; `Appwork::Chorus::ApplicationController` honors a `?locale=` param
against whatever locales the host has configured. The dummy app demonstrates this
with a Spanish (`es.yml`) locale.

## Skill catalog

Chorus mirrors the external agent-skills ecosystem (the `npx skills` registry,
backed by skills.sh) into local `chorus_*` tables you can join and query fast,
alongside `chorus.org`'s curation verdicts and your own category taxonomy. Three
tables carry this:

- `Appwork::Chorus::CatalogSkill` — a local mirror of an upstream skill, keyed by the
  natural key `[resource, skill_name]` (`resource` is `owner/repo`; `skill_name`
  is `nil` for a whole-repo entry).
- `Appwork::Chorus::Curation` — `chorus.org`'s read-only verdict for a skill: a
  `reputation` graded `0..100`. Three states, by row presence: **absent** =
  no verdict (unknown), **`0`** = reviewed and flagged (bottom of the scale, not
  a block), **`1..100`** = graded quality.
- `Appwork::Chorus::Taxonomy` — a standalone, hand-seeded category dimension (with an
  optional `parent` for a shallow hierarchy), joined to catalog skills
  many-to-many.

`Appwork::Chorus::SkillCatalog` is the one object that shells out to the CLI and is the
population mechanism for the mirror. **It requires `npx` on `PATH`** (Node) and
reaches the network.

```ruby
catalog = Appwork::Chorus::SkillCatalog.new

# Search the registry (runs `npx skills find`). Returns plain hashes; no DB writes.
hits = catalog.search("react")
# => [{ resource: "vercel-labs/agent-skills", skill_name: "vercel-react-best-practices",
#       description: nil, install_count: 541_800 }, ...]

# Mirror results into appwork_chorus_catalog_skills, upserting on [resource, skill_name].
catalog.ingest(hits)

# Enumerate one repo's skills WITH descriptions (`npx skills add <repo> --list`),
# then mirror those too — a second ingest of the same skill updates, not duplicates.
catalog.ingest(catalog.list_repo_skills("vercel-labs/agent-skills"))

Appwork::Chorus::CatalogSkill.count
```

Query the mirror, categorize it, and read a skill's verdict:

```ruby
skill = Appwork::Chorus::CatalogSkill.find_by(resource: "vercel-labs/agent-skills",
                                     skill_name: "vercel-react-best-practices")

# Categorize it — taxonomy is your own dimension, seeded by hand.
frontend = Appwork::Chorus::Taxonomy.create!(name: "Frontend", slug: "frontend")
skill.taxonomies << frontend

# chorus.org's verdict: nil when unreviewed, else 0..100 (resolved on the natural key).
skill.curation&.reputation
```

Curation rows load from and dump to YAML through `Partitia::Support::YamlSerializable`
(a set of rows round-trips on identity):

```ruby
Appwork::Chorus::Curation.dump_to_yaml("tmp/curations.yml")
Appwork::Chorus::Curation.load_from_yaml("tmp/curations.yml")
```

Installing a chosen skill is a thin wrapper over the CLI. Installs are always
scoped to a path you own — `-g` (global) is never passed unless you ask for it:

```ruby
# Runs `npx skills add <repo> --skill <name> -a claude`, in `path`.
catalog.add("vercel-labs/agent-skills",
            skill: "vercel-react-best-practices",
            agents: %w[claude],
            path: "/path/to/workspace")

catalog.update("vercel-react-best-practices")   # `npx skills update`
catalog.remove("vercel-react-best-practices")   # `npx skills remove`
```

## Configuration

Non-secret configuration resolves through `Appwork::Chorus::Config` (an `anyway_config`
subclass) from, in ascending precedence, `config/appwork_chorus.yml` →
`credentials.chorus` → `ENV["APPWORK_CHORUS_*"]`. A tenant's **curation posture** lives
here rather than on any model:

| Key                    | Default | ENV                          | Meaning                                             |
| ---------------------- | ------- | ---------------------------- | --------------------------------------------------- |
| `curation_enabled`     | `true`  | `APPWORK_CHORUS_CURATION_ENABLED`    | Whether `chorus.org`'s curation is in force.        |
| `reputation_threshold` | `50`    | `APPWORK_CHORUS_REPUTATION_THRESHOLD`| Minimum reputation required when curation is on.    |

```ruby
Appwork::Chorus::Config.curation_enabled      # => true
Appwork::Chorus::Config.reputation_threshold  # => 50
```

Secrets (e.g. the GitHub token used by `Appwork::Chorus::ExternalAccount::GitHub`) resolve
separately through `Appwork::Chorus::Credentials` — set them via `rails credentials:edit`
(under `appwork_chorus_credentials`) or `ENV["APPWORK_CHORUS_GITHUB_TOKEN"]`, never a source
literal.

## Development

```bash
$ bundle exec rspec                       # model specs (request/i18n specs retired with the scaffold UI)
```

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
