require "rails_helper"

# Chorus::Invocation — the coordinator, proven end to end entirely in DRY mode (§6):
# correct argv recorded, skills equipped, Result + Artifact persisted — no model
# spend, no auth, CI-safe. There is NO :live test; the real authed run is a manual
# console act.
RSpec.describe Chorus::Invocation do
  let(:workspace) { create(:chorus_workspace) }
  let(:adapter)   { create(:chorus_agent_adapter_claude_code) }
  let(:agent)     { create(:chorus_agent, agent_adapter: adapter) }
  let(:role)      { create(:chorus_agent_role, :with_requirements) }
  let(:task)      { "Build a Phlex searchable, sortable table component for Rails." }

  subject(:invocation) { described_class.new(agent: agent, role: role, task: task, workspace: workspace) }

  # Dry throughout: neither the npx install nor the claude exec runs.
  before do
    allow(Chorus::Config).to receive(:agents_live).and_return(false)
    allow(Chorus::Config).to receive(:skills_live).and_return(false)
    allow(Chorus::Config).to receive(:skill_copy).and_return(true)
  end

  it "persists a Result with the recorded equip + invoke argv (now with -y and --copy)" do
    result = invocation.call

    expect(result).to be_persisted
    expect(result.argv_for(:equip)).to eq([
      [ "npx", "skills", "add", "vercel-labs/agent-skills", "-y", "--skill", "web-design-guidelines", "-a", "claude-code", "--copy" ],
      [ "npx", "skills", "add", "vercel-labs/agent-skills", "-y", "--skill", "frontend-design", "-a", "claude-code", "--copy" ]
    ])
    expect(result.argv_for(:invoke)).to eq([ [ "claude", "-p", task ] ])
  end

  it "records the project path (the workspace directory) as the cwd for equip and invoke" do
    result = invocation.call

    expect(result.cwd_for(:equip)).to eq([ workspace.directory.to_s, workspace.directory.to_s ])
    expect(result.cwd_for(:invoke)).to eq([ workspace.directory.to_s ])
  end

  it "records which execution-mode switches were in effect" do
    result = invocation.call
    expect(result.agents_live).to be(false)
    expect(result.skills_live).to be(false)
  end

  it "persists an Artifact on the workspace and links it to the Result" do
    result = invocation.call

    expect(result.artifact).to be_persisted
    expect(result.artifact.workspace).to eq(workspace)
    expect(result.artifact.kind).to eq("agent_output")
    # Dry: no output, so a marked placeholder with no locator.
    expect(result.artifact.locator).to be_nil
  end

  it "never shells out in dry mode" do
    expect_any_instance_of(Chorus::AgentAdapter::ClaudeCode).not_to receive(:capture_cli)
    expect_any_instance_of(Chorus::SkillCatalog).not_to receive(:add)
    invocation.call
  end

  it "marks the run successful" do
    expect(invocation.call.success?).to be(true)
  end

  it "raises a clear error when the agent has no adapter" do
    adapterless = create(:chorus_agent, agent_adapter: nil)
    expect {
      described_class.new(agent: adapterless, role: role, task: task, workspace: workspace).call
    }.to raise_error(ArgumentError, /no agent_adapter/)
  end
end
