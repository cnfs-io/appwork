# Roadmap

## D8 — appwork on the partitia names and engine contract (2026-10-22)

- [x] Rename: `appwork-<name>` / `Appwork::<Name>` for chatter, chorus, gtd, manager (was
      micro_manager) and okf (was cnfs_okf); `git mv` so history follows; tables
      `appwork_<name>_*` (migrations edited in place: nothing is released), generators,
      rake, config, i18n keys, factories
- [x] Partitia references on the D1 names (`Partitia::Support`, `partitia-*`); partitia's
      engines by gem name through gem-local, appwork siblings through `../<dir>`
- [x] Gemspecs declare runtime siblings and `required_ruby_version >= 3.2`; lockfiles carry
      arm64-darwin, x86_64-linux-gnu, aarch64-linux-gnu
- [x] Contract: every engine registers; `appwork:<name>:install` for each (re-runnable,
      prints what is left); chorus has one config class (its GitHub token folded in) and
      no host acronym inflection; dummies read the migrations registry in every environment
- [x] gem-local: this repo is a source; `appwork-*` are linked beside `partitia-*`
- [x] Specs green, RuboCop clean, each gem from a fresh clone (gtd: 8 pending, below)

## CI

- [x] An RSpec job beside lint, on one gem matrix (chatter, chorus, gtd, manager, okf), Ruby
      4.0.7 at the top of `.github/workflows/ci.yml`; dependabot follows the renamed dirs
- [ ] First run on GitHub (not pushed yet). If cnfs-io/partitia is private, add a
      `PARTITIA_READ_TOKEN` secret that can read it (the jobs check it out)
- [ ] `pt ci` cannot run this repo: pcm's ruby-ci job mounts only the repo under test, so
      partitia's engines are missing, and it bundles frozen while the lockfiles record this
      machine's gem-local path. It needs partitia (or gem-local's home and its targets)
      mounted and `RUBY_LOCAL_GEMS_HOME` set, and an unfrozen bundle for that path line (as
      the GitHub workflow does)
- [ ] `pt engine check` is hard-wired to `partitia-<dir>.gemspec`, `lib/partitia/<dir>` and
      `lib/generators/partitia/<dir>`. With the prefix taken from the repo (or the gemspec
      found in the dir) it passes every check here except the CI matrix line (now fixed)
      and warns on chatter's ERB views

## What is left, per gem

- [ ] **gtd:** the board half needs partitia-ui's `Board`/`Column`/`Placement`, the Kanban
      components and the reposition endpoint, which partitia-ui does not have (it never
      did in this repo either). 8 examples are skipped with that reason; the dummy's
      `BoardsController`, views and seeds still reference them, and its Tailwind entry
      imports a partitia-ui `tokens.css` that does not exist. Decide whether boards belong
      in partitia-ui (D9) or here
- [ ] **events:** `Partitia::Support.component_tag` tags by the first namespace segment, so
      every appwork event is `partitia_appwork.<class>.<verb>` (okf's `sync.run` and chorus'
      `source.fetch` share one component). `appwork_<name>.*` needs support to treat
      `Appwork::<Name>` like `Partitia::<Name>`, and telemetry to subscribe to it (a
      partitia change)
- [ ] **chatter:** views are ERB (Phlex with partitia's D9). `install_dev` writes fake auth
      for throwaway apps only
- [ ] **chorus:** `AGENTS.md`, `README.md` and `ARCHITECTURE-testing-scope.md` still describe
      the Workspace as the occupier of a workable in places; since plan 011 the subject
      rides on WorkOrder. Needs a readme-authoring pass
- [ ] **manager:** no routes or views; its specs were moved onto chorus' WorkOrder API (they
      predated it)
- [ ] **okf, chorus, gtd, manager:** none is proven in a fresh `rails new` app yet (partitia
      D3's standard: install twice, the second leaving `git status` clean)
- [ ] `progress.md`, `patrol.md` and the plan files are history: renamed where mechanical,
      not rewritten

**What an agent needs to know (D8):**
- Partitia's engines come from gem-local: the Gemfiles read `RUBY_LOCAL_GEMS_HOME` (as
  partitia's app template does), so `Gemfile.lock` records this machine's absolute path.
  Another machine or CI bundles with `BUNDLE_FROZEN=false`; only that path line changes.
- `gem-local build` relinks everything from `~/.config/ruby/local-gems` (this repo is listed
  there); run it after adding or renaming a gem.
- A dummy's test database loads `spec/dummy/db/schema.rb`. Regenerate it from migrations,
  not by hand: delete it, migrate a throwaway database
  (`DATABASE_URL=sqlite3:/tmp/x.sqlite3 RAILS_ENV=development bin/rails db:migrate
  db:schema:dump` in `spec/dummy`). An existing schema.rb can seed a fresh database and
  hide a stale table.
- Specs moved one directory deeper by the rename (`spec/models/appwork/<name>/`); relative
  fixture paths need `../../../fixtures`.
- partitia-ui's initializers require `app/components` in the host: gtd's dummy keeps a
  `.keep` there.
- The URN partition is `Partitia::Support::UrnConfig` (ADR 0007); no appwork gem mints URNs
  yet.

## Later: feature flags

- [ ] appwork engines gate their features through partitia-support's seam
      `Partitia::Support.feature?(name, actor:)` (partitia ROADMAP D6.5), so they support
      [flipper](https://github.com/flippercloud/flipper) without depending on it. The app wires
      flipper; the testbed (`~/spaces/cnfs/apps/testbed`) proves it

## Later: fresh-app proof

- [ ] Each engine installed into a fresh app: the testbed's `kitchen-sink` recipe (partitia
      D6.5) once the resolver handles appwork engines
