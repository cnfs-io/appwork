# AGENTS.md — appwork

Rails engines for functionality only some CNFS apps need: chatter, chorus, gtd, manager, okf.
One gem per directory (`<dir>/appwork-<dir>.gemspec`, module `Appwork::<Name>`), built on
partitia's engines (`partitia-support` everywhere) and held to partitia's engine contract.

Read first:

- `ROADMAP.md` — what is done, what is left per gem, and what an agent needs to know.
- partitia's `ARCHITECTURE.md` (the engine contract) and `AGENTS.md`, in the partitia repo
  (`gem-local path partitia-support`, then its parent).
- `<gem>/AGENTS.md` where a gem has one (chorus), then its `README.md` and `progress.md`
  (`progress.md` is a history log, not maintained docs).

Working here:

- Each gem stands alone: `cd <gem> && bundle exec rspec`, `bin/rubocop`. appwork siblings
  resolve through Gemfile `path: "../<dir>"` entries; partitia's engines by gem name from
  gem-local's links (`RUBY_LOCAL_GEMS_HOME`, `gem-local list`). After adding or renaming a
  gem: `gem-local build`.
- Names: gem `appwork-<name>`, require `appwork/<name>`, tables `appwork_<name>_*`,
  generators `appwork:<name>:install`, rake `appwork:<name>:*`, config
  `config_name :appwork_<name>` (`APPWORK_<NAME>_*`).
- Commit to main; the person reviews and pushes.
