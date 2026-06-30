require "rails_helper"

RSpec.describe Chorus::Project, type: :model do
  it "has a valid factory" do
    expect(build(:chorus_project)).to be_valid
  end

  describe "validations" do
    it "requires a name" do
      project = build(:chorus_project, name: nil)
      expect(project).not_to be_valid
      expect(project.errors[:name]).to be_present
    end

    it "requires a goal" do
      expect(build(:chorus_project, goal: nil)).not_to be_valid
    end
  end

  describe "associations" do
    it { expect(described_class.reflect_on_association(:goal).macro).to eq(:belongs_to) }
    it { expect(described_class.reflect_on_association(:issues).macro).to eq(:has_many) }

    it "reaches strategy through goal" do
      reflection = described_class.reflect_on_association(:strategy)
      expect(reflection.macro).to eq(:has_one)
      expect(reflection.options[:through]).to eq(:goal)
    end

    it "reaches organization through goal" do
      reflection = described_class.reflect_on_association(:organization)
      expect(reflection.macro).to eq(:has_one)
      expect(reflection.options[:through]).to eq(:goal)
    end

    it "returns the organization up the intent spine" do
      org = create(:chorus_organization)
      strategy = create(:chorus_strategy, organization: org)
      goal = create(:chorus_goal, strategy: strategy)
      project = create(:chorus_project, goal: goal)
      expect(project.organization).to eq(org)
    end
  end

  describe "hosting workspace (the active slot)" do
    it "is the workspace whose active_project points at it" do
      project = create(:chorus_project)
      workspace = create(:chorus_workspace, active_project: project)
      expect(project.reload.hosting_workspace).to eq(workspace)
    end

    it "nullifies the hosting workspace's active slot when destroyed" do
      project = create(:chorus_project)
      workspace = create(:chorus_workspace, active_project: project)

      project.destroy

      expect(workspace.reload.active_project_id).to be_nil
      expect(Chorus::Workspace.exists?(workspace.id)).to be(true)
    end
  end

  describe "dependent destruction" do
    it "destroys its issues when destroyed" do
      project = create(:chorus_project)
      issue = create(:chorus_issue, project: project)

      project.destroy

      expect(Chorus::Issue.exists?(issue.id)).to be(false)
    end
  end
end
