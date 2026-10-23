# Gtd (appwork-gtd)

`Appwork::Gtd` is Getting Things Done on appwork's layers: `Action`, `Project` and
`Context` (tables `appwork_gtd_*`). An `Action` owns an OKF concept (its content lives on
disk, through `appwork-okf`), carries a workflow `status`, and is meant to appear on
partitia-ui boards as a placement subject (ADR 0005), where a move between workflow
columns asserts a status change (ADR 0006).

**Status: the board half does not work.** It needs partitia-ui's
`Board`/`Column`/`Placement` and Kanban components, which partitia-ui does not have; the
specs that need them are skipped with that reason (see the repo `ROADMAP.md`). The OKF
content half works.

## Installation

```ruby
# Gemfile: appwork's and partitia's gems by name, from gem-local's links (gem-local list)
local_gems = ENV.fetch("RUBY_LOCAL_GEMS_HOME") { File.join(ENV.fetch("XDG_DATA_HOME") { File.join(Dir.home, ".local/share") }, "gems") }
gem "partitia-support", path: "#{local_gems}/partitia-support"
gem "partitia-ui", path: "#{local_gems}/partitia-ui"
gem "appwork-okf", path: "#{local_gems}/appwork-okf"
gem "appwork-gtd", path: "#{local_gems}/appwork-gtd"
```

```bash
bin/rails generate partitia:support:install   # database.yml reads the engines' migrations
bin/rails generate appwork:okf:install
bin/rails generate appwork:gtd:install        # checks the wiring, prints what is left; re-runnable
bin/rails db:migrate
```

## Development

```bash
bundle exec rspec     # 8 board examples pending until partitia-ui has boards
bin/rubocop
```

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
