# Appwork::Okf

A filesystem-backed content engine for [OKF](https://okf.org)-style Markdown.
A **bundle** is a directory of `.md` files; each file becomes a **concept** row
whose YAML frontmatter is projected onto columns. `Appwork::Okf` keeps that database
projection reconciled with what's on disk — the files are the source of truth,
the rows are a queryable index over them.

Any of your own models can **own** a concept (or a whole bundle) through a
polymorphic association, so your domain records and the on-disk content stay
linked without `Appwork::Okf` knowing anything about your models.

## Installation

Add the gem (it depends on `partitia-support`):

```ruby
# Gemfile: appwork's and partitia's gems by name, from gem-local's links (gem-local list)
local_gems = ENV.fetch("RUBY_LOCAL_GEMS_HOME") { File.join(ENV.fetch("XDG_DATA_HOME") { File.join(Dir.home, ".local/share") }, "gems") }
gem "partitia-support", path: "#{local_gems}/partitia-support"
gem "appwork-okf", path: "#{local_gems}/appwork-okf"
```

Then wire it and migrate (creates `appwork_okf_bundles`, `appwork_okf_concepts`,
`appwork_okf_view_ports`):

```bash
bundle install
bin/rails generate partitia:support:install   # database.yml reads the engines' migrations
bin/rails generate appwork:okf:install        # checks that, prints what is left; re-runnable
bin/rails db:migrate
```

`Appwork::Okf` is a Rails engine registered with `Partitia::Support.plugins`; its
migrations run in place from the gem (never copied), and its models and rake tasks
load once the gem is in your `Gemfile`. There are no routes to mount —
the public surface is the models, `Appwork::Okf::Sync`, and the rake tasks below.

## Quick start

Point a bundle at a directory of Markdown. Creating the bundle reconciles it
immediately — every `.md` under the root becomes a concept:

```ruby
# /content/notes/welcome.md:
#   ---
#   title: Welcome
#   tags: [intro]
#   ---
#   Hello.

bundle = Appwork::Okf::Bundle.create!(path: "/content/notes")

bundle.concepts.count                       # => 1
concept = bundle.concepts.find_by!(path: "welcome.md")
concept.title                               # => "Welcome"
concept.tags                                # => ["intro"]
concept.content                             # => "Hello.\n"  (body, frontmatter stripped)
```

Frontmatter keys that match a column (`type`, `title`, `description`,
`resource`, `tags`, `timestamp`) populate that column; any other key is kept in
`custom_frontmatter`.

## Common tasks

### Reconcile a bundle against disk

`Appwork::Okf::Sync` is the single entry point for reconciliation. It is idempotent —
a second call with no on-disk changes does nothing — so running it more often
than necessary is only a cost in time, never in correctness.

```ruby
Appwork::Okf::Sync.call(bundle: bundle)                        # whole bundle
Appwork::Okf::Sync.call(bundle: bundle, paths: ["welcome.md"]) # just these files
```

Editing a concept's frontmatter attribute writes back to the file:

```ruby
concept.update!(title: "Welcome!")   # rewrites welcome.md's frontmatter on disk
```

### Browse a sub-tree

A `ViewPort` scopes a bundle to a subdirectory:

```ruby
bundle.ls("guides")     # concepts under guides/ (an ActiveRecord::Relation)
bundle.tree             # the unique set of directories the bundle spans
```

### Move a bundle

`#mv` renames the directory and updates the record. A move on the same
filesystem is detected and skips reconciliation (the files are the same inodes):

```ruby
bundle.mv("/content/archive/notes")   # => true on success, false (logged) on failure
```

### Own content from your models

Include `Appwork::Okf::Consumer` and declare the association. Ownership drives the
`owned_concept_policy` (see Configuration) — a concept with an owner is treated
as more than a disk mirror.

```ruby
class Account < ApplicationRecord
  include Appwork::Okf::Consumer

  has_one_okf  :concept    # one owned Appwork::Okf::Concept
  has_one_okf  :bundle     # ...or a whole bundle
  # has_many_okf :concepts # ...or many
end

concept.update!(owner: account)   # claim it
account.concept                   # => the owned concept
```

### Watch and auto-sync (development)

`bin/rails appwork:okf:sync` reconciles once; `appwork:okf:listen` watches the bundle
roots and reconciles on every change. Both take an optional `BUNDLE=<id>` to
scope to one bundle:

```bash
bin/rails appwork:okf:sync                 # reconcile every bundle once
BUNDLE=42 bin/rails appwork:okf:sync       # reconcile just bundle 42
bin/rails appwork:okf:listen               # watch all bundles, sync on change (blocks)
```

`appwork:okf:listen` blocks and runs a background watcher thread — run it as a
**dedicated process** (a `Procfile.dev` entry or a systemd unit), never inside a
web or job process.

## Configuration

Settings live on `Appwork::Okf::Config` (`config_name :appwork_okf`) and resolve from
`config/appwork_okf.yml`, then credentials (`appwork_okf`), then `APPWORK_OKF_*`; an
initializer can also set them:

```ruby
# config/initializers/appwork_okf.rb
Appwork::Okf::Config.owned_concept_policy = :quarantine
```

| Key | Default | Meaning |
| --- | --- | --- |
| `owned_concept_policy` | `:protect` | How a disk change to an **owned** concept is handled: `:disk_wins` (apply or delete), `:protect` (apply content, never delete), `:quarantine` (leave the DB untouched so the concept reads as `diverged?`). Unowned concepts always follow disk. |
| `listen_latency` | `0.5` | Seconds `appwork:okf:listen` coalesces filesystem events before reconciling. |
| `listen_only` | `/\.md\z/` | Regexp of paths the watcher reacts to. |

appwork-okf has no secrets.

## Events

Instrumented through `Partitia::Support::Instrumentable`: `sync.run` and `concept.persist`,
emitted as `partitia_appwork.sync.run` and `partitia_appwork.concept.persist` (support tags
every `Appwork::*` constant `partitia_appwork`; see the repo ROADMAP).

## Development

Specs run against the bundled dummy app in `spec/dummy`:

```bash
bundle exec rspec     # the dummy's test schema loads itself (maintain_test_schema!)
bundle exec rubocop
```

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
