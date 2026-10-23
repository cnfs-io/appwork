require "rails_helper"
require "tmpdir"

# Appwork::Chorus::WorkOrder#execute! (plan 011 §10, absorbing 010's Planner). Proven end to
# end with a STUBBED agent that "writes" a file (to the path Chorus embedded in the
# prompt) and yields fake events. No live `claude` in the suite — this is
# coordination-only testing: path selection, sync, ownership, the type stamp, and the
# recorded Result.
#
# The host seeds a bundle at the workspace directory and points the workspace's
# viewport at a subpath ("planning") — so concept paths carry that prefix and the
# test genuinely exercises the viewport-relative anchor (not a bare "plans/...").
RSpec.describe Appwork::Chorus::WorkOrder, "#execute!", type: :model do
  let(:root) { Dir.mktmpdir("chorus-execute") }
  before { allow(Appwork::Chorus::Config).to receive(:workspace_root).and_return(root) }
  after  { FileUtils.remove_entry(root) if File.exist?(root) }

  let(:workspace) { create(:appwork_chorus_workspace) }
  let(:bundle)    { Appwork::Okf::Bundle.create!(path: workspace.pathname.to_s) }
  let!(:viewport) { workspace.create_view_port!(bundle: bundle, path: "planning", materialize: true) }

  let(:architect) { create(:appwork_chorus_role, name: "rails-architect") }
  let(:swe)       { create(:appwork_chorus_role, name: "rails-swe") }
  let(:agent)     { create(:appwork_chorus_agent) }

  subject(:work_order) do
    create(:appwork_chorus_work_order, workspace: workspace, role: architect, agent: agent)
  end

  # A fake agent: reads the path Chorus told it to write (embedded in the prompt),
  # writes a frontmatter-less markdown body there, streams a couple of events (the
  # terminal :result carrying session/cost), and returns a Shell::Result — the
  # observable shape of a real run.
  def stub_agent_writing(body: "# Auth plan\n\nAdd sign-in and sign-out.\n")
    allow(agent).to receive(:invoke) do |prompt:, workspace:, **_rest, &block|
      rel = prompt[%r{[\w./-]+\.md}]
      target = workspace.pathname.join(rel)
      target.dirname.mkpath
      target.write(body)
      block&.call({ type: :text, text: "working…" })
      block&.call({ type: :result, session_id: "sess-x", cost_usd: 0.0123,
                    duration_ms: 4567, num_turns: 3, usage: { "output_tokens" => 200 },
                    is_error: false })
      Partitia::Support::Shell::Result.new(command: %w[claude], stdout: "", stderr: "", exitstatus: 0, shellout: nil)
    end
  end

  describe "the happy path" do
    before { stub_agent_writing }

    it "returns a persisted Plan addressed to plan_role, owning the viewport concept" do
      plan = work_order.execute!(slug: "user-auth", plan_role: swe)

      expect(plan).to be_persisted
      expect(plan.work_order).to eq(work_order)
      expect(plan.role).to eq(swe)                 # WHO EXECUTES IT — distinct from work_order.role
      expect(plan.agent).to eq(agent)
      expect(plan.name).to eq("user-auth")
    end

    it "picks a viewport-relative concept path carrying the viewport prefix" do
      plan = work_order.execute!(slug: "user-auth", plan_role: swe)
      expect(plan.concept.path).to eq("planning/plans/001-user-auth.md")
    end

    it "stamps type: plan through OKF, preserving the agent's body verbatim" do
      plan = work_order.execute!(slug: "user-auth", plan_role: swe)

      expect(plan.concept.type).to eq("plan")
      file = plan.concept.pathname.read
      expect(file).to start_with("---\n")
      expect(file).to match(/^type: plan$/)
      expect(file).to include("# Auth plan")
      expect(file).to include("Add sign-in and sign-out.")
    end

    it "claims ownership of the concept (so sync will not treat it as disk-wins)" do
      plan = work_order.execute!(slug: "user-auth", plan_role: swe)
      expect(plan.concept.owner).to eq(plan)
      expect(plan.concept.reload.owner_id).to be_present
    end

    it "records the invocation as a Result on the work order" do
      work_order.execute!(slug: "user-auth", plan_role: swe)

      result = work_order.results.last
      expect(result.success).to be(true)
      expect(result.external_session_id).to eq("sess-x")
      expect(result.cost_usd).to eq(0.0123)
      expect(result.num_turns).to eq(3)
      expect(result.cwd).to eq(workspace.pathname.to_s)
    end

    it "latches external_session_id onto the work order from the stream" do
      work_order.execute!(slug: "user-auth", plan_role: swe)
      expect(work_order.reload.external_session_id).to eq("sess-x")
    end
  end

  describe "path selection" do
    before { stub_agent_writing }

    it "starts at 001 in an empty viewport" do
      plan = work_order.execute!(slug: "user-auth", plan_role: swe)
      expect(plan.concept.path).to eq("planning/plans/001-user-auth.md")
    end

    it "picks the next sequence when plans already exist" do
      plans_dir = viewport.pathname.join("plans")
      plans_dir.mkpath
      plans_dir.join("001-old.md").write("# old\n")
      plans_dir.join("002-older.md").write("# older\n")

      plan = work_order.execute!(slug: "user-auth", plan_role: swe)
      expect(plan.concept.path).to eq("planning/plans/003-user-auth.md")
    end
  end

  describe "failure: the agent wrote no file" do
    it "records a failed Result and raises" do
      allow(agent).to receive(:invoke) do |**_kw, &block|
        block&.call({ type: :text, text: "I refuse" })
        Partitia::Support::Shell::Result.new(command: %w[claude], stdout: "", stderr: "", exitstatus: 0, shellout: nil)
      end

      expect { work_order.execute!(slug: "user-auth", plan_role: swe) }
        .to raise_error(/did not write the plan file/)

      expect(work_order.results.last.success).to be(false)
    end
  end
end
