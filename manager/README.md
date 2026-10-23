# Manager (appwork-manager)

`Appwork::Manager` is an organization's intent spine: `Strategy` → `Goal` → `Project` →
`Ticket` (tables `appwork_manager_*`). Each is an OKF consumer (its `status` lives in its
concept's frontmatter, through `appwork-okf`) and a Chorus workable (the subject of
`Appwork::Chorus::WorkOrder`s, through `appwork-chorus`); a ticket can be assigned to a
Chorus agent. It was extracted from Chorus, so Chorus holds no org chart of its own.

## Installation

```ruby
# Gemfile: appwork's and partitia's gems by name, from gem-local's links (gem-local list)
local_gems = ENV.fetch("RUBY_LOCAL_GEMS_HOME") { File.join(ENV.fetch("XDG_DATA_HOME") { File.join(Dir.home, ".local/share") }, "gems") }
gem "partitia-support", path: "#{local_gems}/partitia-support"
gem "appwork-okf", path: "#{local_gems}/appwork-okf"
gem "appwork-chorus", path: "#{local_gems}/appwork-chorus"
gem "appwork-manager", path: "#{local_gems}/appwork-manager"
```

```bash
bin/rails generate partitia:support:install   # database.yml reads the engines' migrations
bin/rails generate appwork:okf:install
bin/rails generate appwork:chorus:install
bin/rails generate appwork:manager:install    # checks the wiring, prints what is left; re-runnable
bin/rails db:migrate
```

There are no routes or views yet.

## Development

```bash
bundle exec rspec
bin/rubocop
```

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
