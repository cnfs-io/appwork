# The dummy app plays "the enclosing app". It delegates to the engine's own
# seed routine so Roberto can explore the seeded org chart from the console:
#
#   Chorus::Organization.first.projects                       # through strategies → goals
#   Chorus::Organization.first.strategies.first.goals.first.projects
#   Chorus::Workspace.first.active_project.issues
#   Chorus::Workspace.first.artifacts
#   Chorus::Issue.first.project.organization
#
require "chorus/seeds"
Chorus::Seeds.seed!
