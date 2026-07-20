require "rails_helper"

RSpec.describe Chorus::AgentAdapter, type: :model do
  describe "the STI base" do
    it "cannot be persisted without a concrete type" do
      base = Chorus::AgentAdapter.new(name: "bare")
      expect(base).not_to be_valid
      expect(base.errors[:type]).to be_present
    end

    it "requires a name" do
      adapter = build(:chorus_agent_adapter_claude_code, name: nil)
      expect(adapter).not_to be_valid
      expect(adapter.errors[:name]).to be_present
    end

    it "leaves the invocation interface unimplemented" do
      base = Chorus::AgentAdapter.new
      result = build(:chorus_result)
      expect { base.invoke(task: "t", role: nil, result: result, workspace: nil) }.to raise_error(NotImplementedError)
      expect { base.skills_agent_key }.to raise_error(NotImplementedError)
    end

    it "keeps its associations (agents, concept)" do
      expect(described_class.reflect_on_association(:agents).macro).to eq(:has_many)
      expect(described_class.reflect_on_association(:concept).macro).to eq(:has_one)
    end

    it "resolves the concrete class from the type column" do
      adapter = create(:chorus_agent_adapter_claude_code)
      expect(Chorus::AgentAdapter.find(adapter.id)).to be_a(Chorus::AgentAdapter::ClaudeCode)
    end
  end

  # Both runtimes are proven identically (§6): skills_agent_key + argv construction,
  # unit-tested in DRY mode — the argv is recorded into the Result but never run.
  # No :live test, no model spend, no auth.
  shared_examples "a CLI runtime adapter" do |factory:, agent_key:, expected_argv:|
    let(:adapter) { create(factory) }
    let(:result) { build(:chorus_result) }
    # The run's workspace directory is the cwd (§4). A double so the unit spec
    # asserts cwd threading without touching disk.
    let(:ws_path)   { Pathname.new("/tmp/chorus-ws-spec") }
    let(:workspace) { instance_double(Chorus::Workspace, directory: ws_path, pathname: ws_path) }

    it "declares its skills_agent_key" do
      expect(adapter.skills_agent_key).to eq(agent_key)
    end

    context "in dry mode (agents_live: false)" do
      before { allow(Chorus::Config).to receive(:agents_live).and_return(false) }

      it "records the would-run argv AND the project cwd, and does not exec" do
        expect(adapter).not_to receive(:capture_cli)
        output = adapter.invoke(task: "Build a table", role: nil, result: result, workspace: workspace)

        expect(output).to be_nil
        expect(result.argv_for(:invoke)).to eq([ expected_argv ])
        expect(result.cwd_for(:invoke)).to eq([ ws_path.to_s ])
      end
    end

    context "in live mode (agents_live: true)" do
      before { allow(Chorus::Config).to receive(:agents_live).and_return(true) }

      # The shell seam now returns a normalized CnfsSupport::Shell::Result; on
      # success invoke returns its stdout. Stubbed — never a real run.
      it "records the argv AND drives the shell seam in the workspace cwd, returning stdout" do
        shell = CnfsSupport::Shell::Result.new(
          command: expected_argv, stdout: "stubbed output", stderr: "", exitstatus: 0, shellout: nil
        )
        allow(adapter).to receive(:capture_cli).and_return(shell)
        output = adapter.invoke(task: "Build a table", role: nil, result: result, workspace: workspace)

        expect(output).to eq("stubbed output")
        expect(adapter).to have_received(:capture_cli).with(*expected_argv, cwd: ws_path)
        expect(result.argv_for(:invoke)).to eq([ expected_argv ])
      end

      it "records an operational failure into the Result instead of raising" do
        shell = CnfsSupport::Shell::Result.new(
          command: expected_argv, stdout: "", stderr: "boom", exitstatus: 2, shellout: nil
        )
        allow(adapter).to receive(:capture_cli).and_return(shell)
        output = adapter.invoke(task: "Build a table", role: nil, result: result, workspace: workspace)

        expect(output).to be_nil
        expect(result.success).to be(false)
        expect(result.full_messages.join).to match(/invoke.*exited 2.*boom/)
      end
    end
  end

  describe Chorus::AgentAdapter::ClaudeCode do
    it_behaves_like "a CLI runtime adapter",
      factory: :chorus_agent_adapter_claude_code,
      agent_key: "claude-code",
      expected_argv: [ "claude", "-p", "Build a table" ]
  end

  describe Chorus::AgentAdapter::OpenCode do
    it_behaves_like "a CLI runtime adapter",
      factory: :chorus_agent_adapter_open_code,
      agent_key: "opencode",
      expected_argv: [ "opencode", "run", "Build a table" ]
  end
end
