# The dummy app plays "the enclosing app" (the Chorus host). It supplies a bare
# host workable and delegates to the engine's idempotent seed routine, which sets
# up the 007 "frontend-builder" console scenario.
#
# After `bin/rails db:seed`, in `bin/rails console`:
#
#   agent = Appwork::Chorus::Agent.find_by(name: "Frontend Builder")
#   role  = Appwork::Chorus::Role.find_by(name: "frontend-builder")
#   task  = "Build a Phlex searchable, sortable table component for Rails: a view " \
#           "component taking rows and columns, rendering a semantic HTML table " \
#           "with a search input that filters rows. Choose server-side (Turbo) or " \
#           "client-side (Stimulus) filtering and justify the choice."
#   result = Appwork::Chorus::Invocation.new(agent:, role:, task:).call
#   result.success?          # => true/false
#   result.full_messages     # => [...]
#   result.artifact          # => the built Phlex component, durable
#   result.recorded_argv     # => the equip + invoke argv (would-run in dry mode)
#
# Dry by default (APPWORK_CHORUS_AGENTS_LIVE=false); a REAL `claude -p` build when
# APPWORK_CHORUS_AGENTS_LIVE=true (and Roberto is authed). Either way the Result +
# Artifact are persisted and queryable: Appwork::Chorus::Result.last, Appwork::Chorus::Artifact.last.
require "appwork/chorus/seeds"

# WorkableDummy is the dummy's own bare host model — the workable the Workspace
# occupies. Chorus never names it; the host passes it in.
workable = WorkableDummy.find_or_create_by!(name: "frontend-table")
Appwork::Chorus::Seeds.seed!(workable: workable)
