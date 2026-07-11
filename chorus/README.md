# Chorus

Chorus is a mountable Rails engine that owns the **organizational structure** of a
collaborative system: strategies, goals, roles, agents (human or AI
participants), workspaces, projects, issues, and artifacts. It ships as a
complete domain — full CRUD, seeds, and specs. Narrative content is backed by OKF
(`cnfs_okf`) concepts through a one-directional dependency: Chorus consumes OKF;
OKF never knows Chorus.

Chorus holds **no `Organization` model**: under `cnfs_tenanted` there is one
database per account, and that database *is* one organization. Strategy, Role,
Workspace, and Agent are therefore top-level roots, scoped by the database rather
than by an owning column.

## Domain

Ownership flows down an explicit **intent spine** from strategy to execution; a
project reaches its strategy through its goal, never through a workspace.

```
Strategy     1───* Goal        (Goal belongs_to strategy)
Goal         1───* Project     (Project belongs_to goal)
Project      1───* Issue       (destroy)
Strategy     1───* Project     (through: goals)

Role         1───* Agent       (nullify on role delete)
Agent        0──1  Role        (Agent belongs_to role, optional)
Agent        1───* Issue       (assignee; nullify)
```

The **execution surface** is separate from the intent spine. A workspace is
durable and serial: it outlives any single project and hosts exactly one *active*
project at a time, retaining nothing else about project history.

```
Workspace    0──1  Project     (active_project_id; nullable, nullify)
Workspace    1───* Artifact    (destroy)
```

An `Artifact` is first-class and type-open: a workspace holds many artifacts of
different `kind`s (e.g. `git_repo`, `okf_bundle`), each with a free-form
`locator`. Chorus blesses no artifact type. An agent meets a workspace only by
claiming an issue whose project occupies that workspace's active slot — there is
no direct agent↔workspace link.

All tables are `chorus_`-prefixed; all models live under `Chorus::` (the engine
uses `isolate_namespace Chorus`). `status` and `kind` are deliberately free
strings — the host app owns those vocabularies.

## Installation

Add to your application's Gemfile:

```ruby
gem "chorus"
```

Mount it and install/run the migrations:

```ruby
# config/routes.rb
mount Chorus::Engine => "/chorus"
```

```bash
$ bin/rails db:migrate   # the engine's migrations are picked up automatically
$ bin/rails chorus:seed  # optional: a realistic demo domain
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
additional locales; `Chorus::ApplicationController` honors a `?locale=` param
against whatever locales the host has configured. The dummy app demonstrates this
with a Spanish (`es.yml`) locale.

## Development

```bash
$ bundle exec rspec                       # model + request + i18n specs
$ cd spec/dummy && bin/rails tailwindcss:build
$ cd spec/dummy && bin/rails server       # browse the resources at /chorus
```

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
