# ⚠️  DEV/TEST SCAFFOLD — written by `bin/rails g appwork:chatter:install_dev`.
# Wires the host contract chatter needs. In a real host you write these three
# lines yourself, pointing at your OWN base controller and participant models —
# the generator only scaffolds them for a throwaway dev target. Safe to delete
# when done (but then chatter won't know who current_participant is).

# The engine's Appwork::Chatter::ApplicationController inherits from this, so it picks up
# the host's `current_participant` automatically.
Appwork::Chatter.parent_controller = "::ApplicationController"

# Render the engine's screens inside the host layout (which carries the switcher).
Rails.application.config.to_prepare do
  Appwork::Chatter::ApplicationController.layout "application"
end

# The host knows its participant models; the engine does not. Expose every Person
# and Agent as a candidate to start conversations with.
Appwork::Chatter.participant_candidates = -> { Person.all.to_a + Agent.all.to_a }
