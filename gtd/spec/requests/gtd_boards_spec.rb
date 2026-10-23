# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

# Tier 5 — THE END-TO-END PROOF (Plan 012's headline asymmetry).
#
# One set of Appwork::Gtd::Actions, three boards on the SAME Placement machinery, three
# behaviors when a card moves:
#   Workflow (columns ARE the status enum) → drives the domain (status changes).
#   Context / Project (plain columns)      → pure views (nothing changes).
#   Reorder within a column                → position only, no domain.
#
# Driven the durable way (Plan 011's approach): we replay the exact PATCH the
# shipped partitia-ui--sortable controller sends — { ids:, list_id:, new_position: } —
# against the engine's mounted reposition endpoint. A JS-driver system spec is
# deferred (no headless-browser driver is wired into this dummy).
RSpec.describe "GTD boards", type: :request,
                              skip: "partitia-ui has no Board/Column/Placement or Kanban components yet (appwork ROADMAP)" do
  # A WORKFLOW board: its four columns ARE the status enum (ADR 0006). Each
  # declares status:<value>, so a move INTO one asserts that status.
  let(:workflow) { Partitia::Ui::Board.create!(name: "Workflow") }
  let(:wf_next) do
    workflow.columns.create!(name: "Next", assertion_attribute: "status", assertion_value: "next")
  end
  let(:wf_done) do
    workflow.columns.create!(name: "Done", assertion_attribute: "status", assertion_value: "done")
  end

  # A CONTEXT board: plain columns, no assertions — moving here is presentation-only.
  let(:context_board) { Partitia::Ui::Board.create!(name: "Context") }
  let(:ctx_work) { context_board.columns.create!(name: "@work") }
  let(:ctx_home) { context_board.columns.create!(name: "@home") }

  def reposition(ids:, list_id:, new_position:)
    patch partitia_ui.reposition_placements_path,
      params: { ids: Array(ids), list_id: list_id, new_position: new_position }
  end

  describe "the Workflow board DRIVES the domain (ADR 0006)" do
    it "a move from Next to Done changes the action's status to done" do
      action = Appwork::Gtd::Action.create!(status: "next")
      placement = wf_next.placements.create!(subject: action)

      reposition(ids: placement.id, list_id: wf_done.id, new_position: 1)

      expect(response).to have_http_status(:no_content)
      expect(placement.reload.column).to eq(wf_done) # presentation moved
      expect(action.reload.status).to eq("done")      # AND the domain changed
    end
  end

  describe "the Context board is a PURE VIEW (ADR 0005)" do
    it "a move from @work to @home changes NOTHING on the action" do
      action = Appwork::Gtd::Action.create!(status: "next", context: Appwork::Gtd::Context.create!(name: "@work"))
      placement = ctx_work.placements.create!(subject: action)

      # The plain column relays no assertion at all — the guard the whole spike
      # exists to protect (highest-risk step #1).
      expect_any_instance_of(Appwork::Gtd::Action).not_to receive(:satisfy_assertion)

      reposition(ids: placement.id, list_id: ctx_home.id, new_position: 1)

      expect(response).to have_http_status(:no_content)
      expect(placement.reload.column).to eq(ctx_home) # placement moved
      expect(action.reload.status).to eq("next")       # status untouched
      expect(action.context.name).to eq("@work")       # context untouched (not reassigned)
    end
  end

  describe "a reorder WITHIN a column writes position only" do
    it "changes order but drives no domain (no satisfy_assertion)" do
      a = Appwork::Gtd::Action.create!(status: "next")
      b = Appwork::Gtd::Action.create!(status: "next")
      pa = wf_next.placements.create!(subject: a)
      wf_next.placements.create!(subject: b)

      expect_any_instance_of(Appwork::Gtd::Action).not_to receive(:satisfy_assertion)

      reposition(ids: pa.id, list_id: wf_next.id, new_position: 2)

      expect(wf_next.reload.placements.last).to eq(pa) # reordered
      expect(a.reload.status).to eq("next")            # status unchanged
    end
  end

  describe "three placements, not one shared row (ADR 0005)" do
    it "moving a card on Workflow leaves the SAME action's Context card put" do
      action = Appwork::Gtd::Action.create!(status: "next")
      wf_placement  = wf_next.placements.create!(subject: action)
      ctx_placement = ctx_work.placements.create!(subject: action)

      reposition(ids: wf_placement.id, list_id: wf_done.id, new_position: 1)

      expect(wf_placement.reload.column).to eq(wf_done) # this board moved
      expect(ctx_placement.reload.column).to eq(ctx_work) # the other did NOT
    end
  end

  # The rendering half: a card's title comes from the action's OKF concept on
  # disk, through the composition root — partitia-ui binds only `title`, never OKF.
  describe "rendering a board (content flows from disk)" do
    around do |example|
      Dir.mktmpdir("gtd-board") do |root|
        @root = root
        example.run
      end
    end

    it "GET /boards/:id renders the card with the action's frontmatter title" do
      dir = File.join(@root, "gtd")
      FileUtils.mkdir_p(File.join(dir, "actions"))
      File.write(File.join(dir, "actions/ship-it.md"), "---\ntitle: Ship the release\n---\ncut the tag\n")
      bundle = Appwork::Okf::Bundle.create!(path: dir)

      action = Appwork::Gtd::Action.create!(status: "next")
      action.update!(concept: bundle.concepts.find_by!(path: "actions/ship-it.md"))
      wf_next.placements.create!(subject: action)

      get board_path(workflow)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ship the release")
    end

    it "GET /boards lists all three boards" do
      workflow
      context_board
      Partitia::Ui::Board.create!(name: "Project")

      get boards_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Workflow", "Context", "Project")
    end
  end
end
