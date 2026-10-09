require "fileutils"

# Plan 012, Tiers 2 + 3 — the end-to-end spike's data.
#
# Committed fixtures are the source of truth; the seed copies them into a
# gitignored working dir so a run can mutate files (a body edit rewrites the .md)
# without dirtying git. Destructive + idempotent: it resets everything each run.
# Mirrors okf's and cnfs_ui's spec/dummy/db/seeds.rb.
FIXTURES = Rails.root.join("../fixtures/bundles")   # spec/fixtures/bundles
WORKDIR  = Rails.root.join("storage/bundles")       # gitignored, mutable

abort "Fixtures not found at #{FIXTURES}" unless FIXTURES.exist?

FileUtils.rm_rf(WORKDIR)
FileUtils.mkdir_p(WORKDIR)
FileUtils.cp_r("#{FIXTURES}/.", WORKDIR)

# --- Tier 2: the OKF content bundle -----------------------------------------
# after_create -> Sync builds a Concept row from every .md file on disk. Each
# Gtd::Action/Project then CLAIMS its concept (ownership points at a file; it does
# not create one), so title/body flow from disk through the composition root.
bundle = CnfsOkf::Bundle.create!(path: WORKDIR.join("gtd").to_s)

def concept_for(bundle, path)
  bundle.concepts.find_by!(path: path)
end

# --- Domain objects ----------------------------------------------------------
Gtd::Action.destroy_all
Gtd::Project.destroy_all
Gtd::Context.destroy_all

# Contexts (@home / @work / @calls) — plain grouping labels, not concept-owning.
contexts = %w[@home @work @calls].index_with { |name| Gtd::Context.create!(name: name) }

# Projects — concept-owning; their title/notes live on disk. Keyed by the column
# label the project board will use.
projects = {
  "Website Redesign" => "projects/website-redesign.md",
  "Q3 Planning"      => "projects/q3-planning.md",
  "Errands"          => "projects/errands.md"
}.to_h do |name, md|
  project = Gtd::Project.create!(name: name)
  project.update!(concept: concept_for(bundle, md))
  [ name, project ]
end

# Actions — the composition roots. Each row: [concept path, status, context,
# project]. Statuses span all four workflow columns; contexts span all three;
# projects span all three — so every board is non-trivial and every action gets
# a placement on all three boards.
ACTIONS = [
  [ "actions/call-the-bank.md",      "waiting", "@calls", "Q3 Planning" ],
  [ "actions/draft-homepage-copy.md", "next",    "@work",  "Website Redesign" ],
  [ "actions/pick-hero-image.md",     "inbox",   "@home",  "Website Redesign" ],
  [ "actions/review-vendor-quotes.md", "next",   "@work",  "Q3 Planning" ],
  [ "actions/schedule-dentist.md",    "inbox",   "@calls", "Errands" ],
  [ "actions/archive-old-mockups.md", "done",    "@home",  "Website Redesign" ]
].freeze

actions = ACTIONS.map do |md, status, context_name, project_name|
  action = Gtd::Action.create!(
    status: status,
    context: contexts.fetch(context_name),
    project: projects.fetch(project_name)
  )
  action.update!(concept: concept_for(bundle, md))
  action
end

# --- Tier 3: the three boards -----------------------------------------------
# Same actions, three boards, three independent placements per action (ADR 0005 —
# multi-board is free). Only the WORKFLOW board's columns assert; the other two
# are pure views (ADR 0005 / the design note in plan 012).
CnfsUi::Board.destroy_all

# WORKFLOW — columns ARE the `status` enum (ADR 0006). Each column declares
# `status:<value>`; dragging a card into it relays satisfy_assertion -> the
# action's status column changes. This is the ONLY asserting board.
workflow = CnfsUi::Board.create!(name: "Workflow")
workflow_columns = Gtd::Action::STATUSES.to_h do |status|
  column = workflow.columns.create!(
    name: status.capitalize,
    assertion_attribute: "status",
    assertion_value: status
  )
  [ status, column ]
end
actions.each { |a| workflow_columns.fetch(a.status).placements.create!(subject: a) }

# CONTEXT — plain columns, NO assertion. Dragging reorders/moves the placement
# only; it never mutates the action (ADR 0005 — the context board is a pure view).
context_board = CnfsUi::Board.create!(name: "Context")
context_columns = contexts.keys.to_h do |name|
  [ name, context_board.columns.create!(name: name) ]
end
actions.each { |a| context_columns.fetch(a.context.name).placements.create!(subject: a) }

# PROJECT — one plain column per project, NO assertion. View only.
project_board = CnfsUi::Board.create!(name: "Project")
project_columns = projects.keys.to_h do |name|
  [ name, project_board.columns.create!(name: name) ]
end
actions.each { |a| project_columns.fetch(a.project.name).placements.create!(subject: a) }

puts "Seeded: #{CnfsOkf::Bundle.count} bundle, #{CnfsOkf::Concept.count} concepts, " \
     "#{Gtd::Action.count} actions, #{Gtd::Project.count} projects, " \
     "#{Gtd::Context.count} contexts; boards: " \
     "Workflow(##{workflow.id}, asserts status), " \
     "Context(##{context_board.id}, plain), Project(##{project_board.id}, plain); " \
     "#{CnfsUi::Placement.count} placements (3 per action)"
