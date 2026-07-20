require "rails_helper"
require "tmpdir"

# Chorus::Planner — the console entry point (plan 010 §5/§8). Proven end to end
# with a STUBBED adapter that "writes" a file (to the path Chorus embedded in the
# prompt) and yields fake events. No live `claude` in the suite — this is
# coordination-only testing: file discovery, sync, ownership, and the type stamp.
RSpec.describe Chorus::Planner do
  let(:root) { Dir.mktmpdir("chorus-planner") }
  before { allow(Chorus::Config).to receive(:workspace_root).and_return(root) }
  after  { FileUtils.remove_entry(root) if File.exist?(root) }

  let(:adapter)   { create(:chorus_agent_adapter_claude_code) }
  let(:agent)     { create(:chorus_agent, agent_adapter: adapter) }
  let(:workspace) { create(:chorus_workspace) }

  subject(:planner) { described_class.new(agent: agent, workspace: workspace) }

  # A fake agent: it reads the path Chorus told it to write (embedded in the prompt),
  # writes a frontmatter-less markdown body there, streams a couple of events, and
  # returns a Shell::Result — exactly the observable shape of a real run.
  def stub_agent_writing(body: "# Auth plan\n\nAdd sign-in and sign-out.\n")
    allow(agent).to receive(:agent_adapter).and_return(adapter)
    allow(adapter).to receive(:invoke) do |prompt:, workspace:, **_rest, &block|
      rel = prompt[%r{doc/plans/\S+\.md}]
      target = workspace.pathname.join(rel)
      target.dirname.mkpath
      target.write(body)
      block&.call({ type: :text, text: "working…" })
      block&.call({ type: :result, session_id: "sess-x", is_error: false })
      CnfsSupport::Shell::Result.new(command: %w[claude], stdout: "", stderr: "", exitstatus: 0, shellout: nil)
    end
  end

  describe "the happy path" do
    before { stub_agent_writing }

    it "returns a persisted Plan owning a concept at the chosen bundle-relative path" do
      plan = planner.call(prompt: "Plan user auth.", slug: "user-auth")

      expect(plan).to be_persisted
      expect(plan.workspace).to eq(workspace)
      expect(plan.agent).to eq(agent)
      expect(plan.concept.path).to eq("plans/001-user-auth.md")
    end

    it "stamps type: plan through OKF, preserving the agent's body verbatim" do
      plan = planner.call(prompt: "Plan user auth.", slug: "user-auth")

      expect(plan.concept.type).to eq("plan")
      file = plan.concept.pathname.read
      expect(file).to start_with("---\n")
      expect(file).to match(/^type: plan$/)
      expect(file).to include("# Auth plan")
      expect(file).to include("Add sign-in and sign-out.")
    end

    it "claims ownership of the concept (so sync will not treat it as disk-wins)" do
      plan = planner.call(prompt: "Plan user auth.", slug: "user-auth")

      expect(plan.concept.owner).to eq(plan)
      expect(plan.concept.reload.owner_id).to be_present
    end
  end

  describe "path selection" do
    before { stub_agent_writing }

    it "starts at 001 in an empty doc/plans/" do
      plan = planner.call(prompt: "x", slug: "user-auth")
      expect(plan.concept.path).to eq("plans/001-user-auth.md")
    end

    it "picks the next sequence when plans already exist" do
      plans_dir = workspace.pathname.join("doc", "plans")
      plans_dir.mkpath
      plans_dir.join("001-old.md").write("# old\n")
      plans_dir.join("002-older.md").write("# older\n")

      plan = planner.call(prompt: "x", slug: "user-auth")
      expect(plan.concept.path).to eq("plans/003-user-auth.md")
    end
  end

  describe "failure: the agent wrote no file" do
    it "raises a clear error (there is no Result to record into this phase)" do
      allow(agent).to receive(:agent_adapter).and_return(adapter)
      allow(adapter).to receive(:invoke) do |**_kw, &block|
        block&.call({ type: :text, text: "I refuse" })
        CnfsSupport::Shell::Result.new(command: %w[claude], stdout: "", stderr: "", exitstatus: 0, shellout: nil)
      end

      expect { planner.call(prompt: "x", slug: "user-auth") }
        .to raise_error(/did not write the plan file/)
    end
  end
end
