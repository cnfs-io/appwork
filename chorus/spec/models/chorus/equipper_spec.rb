require "rails_helper"

# Chorus::Equipper — the one shared mounter (§2). It records the npx argv + the
# project cwd into the Result always, gates the real SkillCatalog#add on
# Config#skills_live (§8), installs project-scoped INTO the workspace directory (§4),
# and confirms the skill actually landed — recording any failure into the Result
# rather than raising (§5). Unit-tested with the SkillCatalog boundary stubbed.
RSpec.describe Chorus::Equipper do
  let(:adapter) { create(:chorus_agent) }   # the agent IS its runtime now (011 §2)
  let(:result)  { build(:chorus_result) }
  let(:catalog) { instance_double(Chorus::SkillCatalog) }

  # A workspace double — the run's directory is the install target / cwd. No disk.
  let(:ws_path)   { Pathname.new("/tmp/chorus-ws-eq") }
  let(:workspace) { instance_double(Chorus::Workspace, directory: ws_path, pathname: ws_path) }

  let(:resolved) do
    [
      Chorus::SkillResolver::ResolvedSkill.new(name: "web-design-guidelines", resource: "vercel-labs/agent-skills", skill: "web-design-guidelines"),
      Chorus::SkillResolver::ResolvedSkill.new(name: "frontend-design",       resource: "vercel-labs/agent-skills", skill: "frontend-design")
    ]
  end

  subject(:equipper) { described_class.new(adapter: adapter, result: result, workspace: workspace, catalog: catalog) }

  # The real builders drive the recorded argv, so the record can't drift from a run.
  before do
    allow(catalog).to receive(:add_args) { |resource, **opts| Chorus::SkillCatalog.new.add_args(resource, **opts) }
    allow(catalog).to receive(:npx_argv) { |*args| Chorus::SkillCatalog.new.npx_argv(*args) }
    allow(Chorus::Config).to receive(:skill_copy).and_return(true)
  end

  def ok(stdout = "installed")
    CnfsSupport::Shell::Result.new(command: %w[npx skills], stdout: stdout, stderr: "", exitstatus: 0, shellout: nil)
  end

  context "in live mode (skills_live: true)" do
    before { allow(Chorus::Config).to receive(:skills_live).and_return(true) }

    it "installs each skill into the workspace path, keyed to the adapter's agent key" do
      allow(catalog).to receive(:add).and_return(ok)

      equipper.equip(resolved)

      expect(catalog).to have_received(:add)
        .with("vercel-labs/agent-skills", skill: "web-design-guidelines", agents: [ "claude-code" ], path: ws_path)
      expect(catalog).to have_received(:add)
        .with("vercel-labs/agent-skills", skill: "frontend-design", agents: [ "claude-code" ], path: ws_path)
    end

    it "records the equip argv (with -y and --copy) AND the project cwd" do
      allow(catalog).to receive(:add).and_return(ok)
      equipper.equip(resolved)

      expect(result.argv_for(:equip)).to eq([
        [ "npx", "skills", "add", "vercel-labs/agent-skills", "-y", "--skill", "web-design-guidelines", "-a", "claude-code", "--copy" ],
        [ "npx", "skills", "add", "vercel-labs/agent-skills", "-y", "--skill", "frontend-design", "-a", "claude-code", "--copy" ]
      ])
      expect(result.cwd_for(:equip)).to eq([ ws_path.to_s, ws_path.to_s ])
    end

    it "records an operational failure (non-zero install) into the Result, not a raise" do
      failure = CnfsSupport::Shell::Result.new(
        command: %w[npx skills add], stdout: "", stderr: "network down", exitstatus: 1, shellout: nil
      )
      allow(catalog).to receive(:add).and_return(failure)

      equipper.equip([ resolved.first ])

      expect(result.success).to be(false)
      expect(result.full_messages.join).to match(/equip.*web-design-guidelines.*network down/)
    end

    it "detects the 'exited 0 but skill not found' miss and records it (§5)" do
      allow(catalog).to receive(:add).and_return(ok("No matching skills found"))

      equipper.equip([ resolved.first ])

      expect(result.success).to be(false)
      expect(result.full_messages.join).to match(/exited 0 but reported the skill was not found/)
    end

    it "leaves success unset when every skill installs cleanly" do
      allow(catalog).to receive(:add).and_return(ok)
      equipper.equip(resolved)
      expect(result.success).to be_nil   # no failure recorded; Invocation marks it
    end
  end

  context "in dry mode (skills_live: false)" do
    before { allow(Chorus::Config).to receive(:skills_live).and_return(false) }

    it "records the would-run argv + cwd and never installs" do
      expect(catalog).not_to receive(:add)

      equipper.equip(resolved)

      expect(result.argv_for(:equip)).to eq([
        [ "npx", "skills", "add", "vercel-labs/agent-skills", "-y", "--skill", "web-design-guidelines", "-a", "claude-code", "--copy" ],
        [ "npx", "skills", "add", "vercel-labs/agent-skills", "-y", "--skill", "frontend-design", "-a", "claude-code", "--copy" ]
      ])
      expect(result.cwd_for(:equip)).to eq([ ws_path.to_s, ws_path.to_s ])
    end
  end
end
