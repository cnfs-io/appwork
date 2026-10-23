require "rails_helper"

# Appwork::Chorus::Equipper — PARKED after the Result rewrite (plan 011 §8/§12). It no longer
# records argv or failures into the Result (the per-invocation Result is not an
# accumulator); it only installs skills project-scoped into the workspace when
# skills_live, and is a no-op otherwise. The foreman loop will replace it.
RSpec.describe Appwork::Chorus::Equipper do
  let(:adapter) { create(:appwork_chorus_agent) }   # the agent IS its runtime (011 §2)
  let(:catalog) { instance_double(Appwork::Chorus::SkillCatalog) }

  # A workspace double — the run's directory is the install target. No disk.
  let(:ws_path)   { Pathname.new("/tmp/chorus-ws-eq") }
  let(:workspace) { instance_double(Appwork::Chorus::Workspace, directory: ws_path, pathname: ws_path) }

  let(:resolved) do
    [
      Appwork::Chorus::SkillResolver::ResolvedSkill.new(name: "web-design-guidelines", resource: "vercel-labs/agent-skills", skill: "web-design-guidelines"),
      Appwork::Chorus::SkillResolver::ResolvedSkill.new(name: "frontend-design",       resource: "vercel-labs/agent-skills", skill: "frontend-design")
    ]
  end

  subject(:equipper) { described_class.new(adapter: adapter, workspace: workspace, catalog: catalog) }

  def ok(stdout = "installed")
    Partitia::Support::Shell::Result.new(command: %w[npx skills], stdout: stdout, stderr: "", exitstatus: 0, shellout: nil)
  end

  context "in live mode (skills_live: true)" do
    before { allow(Appwork::Chorus::Config).to receive(:skills_live).and_return(true) }

    it "installs each skill into the workspace path, keyed to the agent's skills key" do
      allow(catalog).to receive(:add).and_return(ok)

      equipper.equip(resolved)

      expect(catalog).to have_received(:add)
        .with("vercel-labs/agent-skills", skill: "web-design-guidelines", agents: [ "claude-code" ], path: ws_path)
      expect(catalog).to have_received(:add)
        .with("vercel-labs/agent-skills", skill: "frontend-design", agents: [ "claude-code" ], path: ws_path)
    end
  end

  context "in dry mode (skills_live: false)" do
    before { allow(Appwork::Chorus::Config).to receive(:skills_live).and_return(false) }

    it "installs nothing" do
      expect(catalog).not_to receive(:add)
      equipper.equip(resolved)
    end
  end
end
