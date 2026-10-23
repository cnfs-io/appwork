# The engine's own seed entry point (the standard Rails `db/seeds.rb`). Delegates
# to the idempotent Appwork::Chorus::Seeds routine. A host app that occupies the seeded
# Workspace with one of its own workables passes it in from ITS db/seeds.rb (see
# spec/dummy/db/seeds.rb) — Chorus stays host-agnostic, so this bare entry seeds
# without a workable.
require "appwork/chorus/seeds"

Appwork::Chorus::Seeds.seed!
