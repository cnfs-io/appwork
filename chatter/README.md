# Chatter (appwork-chatter)

`Appwork::Chatter` is a mountable Rails engine for direct and group conversations
between the host's own participant models (people, agents, anything), with messages
delivered live over Turbo Streams. Tables `appwork_chatter_conversations`,
`appwork_chatter_memberships`, `appwork_chatter_messages`.

The engine never names a host model: a participant is any model that includes
`Appwork::Chatter::Participant` (polymorphic memberships and senders).

## Installation

```ruby
# Gemfile: appwork's and partitia's gems by name, from gem-local's links (gem-local list)
local_gems = ENV.fetch("RUBY_LOCAL_GEMS_HOME") { File.join(ENV.fetch("XDG_DATA_HOME") { File.join(Dir.home, ".local/share") }, "gems") }
gem "partitia-support", path: "#{local_gems}/partitia-support"
gem "appwork-chatter", path: "#{local_gems}/appwork-chatter"
```

```bash
bin/rails generate partitia:support:install    # database.yml reads the engines' migrations
bin/rails generate appwork:chatter:install     # mounts /chatter, prints what is left; re-runnable
bin/rails db:migrate
```

Then, as the installer prints:

```ruby
# app/models/person.rb (each model that chats)
include Appwork::Chatter::Participant

# config/initializers/appwork_chatter.rb
Appwork::Chatter.parent_controller = "::ApplicationController"   # must define current_participant
Appwork::Chatter.participant_candidates = -> { Person.all.to_a } # whom a user may start a chat with
```

Unset, `parent_controller` is `ActionController::Base` and any chatter page raises,
saying `current_participant` is missing; `participant_candidates` offers no one.

For a throwaway development app, `bin/rails g appwork:chatter:install_dev` writes
Person/Agent models, a fake-auth identity switcher and seeds (development only; it
refuses to run elsewhere).

## Views

ERB with Tailwind classes and Stimulus controllers `appwork--chatter--messages` and
`appwork--chatter--reset`, pinned through the engine's importmap. Phlex/RubyUI comes
with partitia's D9.

## Development

```bash
bundle exec rspec
bin/rubocop
```

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
