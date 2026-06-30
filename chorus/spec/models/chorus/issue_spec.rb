require "rails_helper"

RSpec.describe Chorus::Issue, type: :model do
  it "has a valid factory" do
    expect(build(:chorus_issue)).to be_valid
  end

  describe "validations" do
    it "requires a title" do
      issue = build(:chorus_issue, title: nil)
      expect(issue).not_to be_valid
      expect(issue.errors[:title]).to be_present
    end

    it "requires a project" do
      expect(build(:chorus_issue, project: nil)).not_to be_valid
    end

    it "is valid without an agent (agent is optional)" do
      expect(build(:chorus_issue, agent: nil)).to be_valid
    end
  end

  describe "associations" do
    it { expect(described_class.reflect_on_association(:project).macro).to eq(:belongs_to) }

    it "marks agent as optional" do
      expect(described_class.reflect_on_association(:agent).options[:optional]).to be(true)
    end
  end

  describe "traversal to organization" do
    it "reaches the organization up the intent spine (project → goal → strategy)" do
      org = create(:chorus_organization)
      strategy = create(:chorus_strategy, organization: org)
      goal = create(:chorus_goal, strategy: strategy)
      project = create(:chorus_project, goal: goal)
      issue = create(:chorus_issue, project: project)

      expect(issue.project.organization).to eq(org)
    end
  end
end
