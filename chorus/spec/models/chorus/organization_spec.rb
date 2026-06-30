require "rails_helper"

RSpec.describe Chorus::Organization, type: :model do
  it "has a valid factory" do
    expect(build(:chorus_organization)).to be_valid
  end

  describe "validations" do
    it "requires a name" do
      org = build(:chorus_organization, name: nil)
      expect(org).not_to be_valid
      expect(org.errors[:name]).to be_present
    end

    it "enforces slug uniqueness but allows blank" do
      create(:chorus_organization, slug: "acme")
      expect(build(:chorus_organization, slug: "acme")).not_to be_valid
      expect(build(:chorus_organization, slug: "")).to be_valid
      expect(build(:chorus_organization, slug: nil)).to be_valid
    end
  end

  describe "associations" do
    it { expect(described_class.reflect_on_association(:strategies).macro).to eq(:has_many) }
    it { expect(described_class.reflect_on_association(:roles).macro).to eq(:has_many) }
    it { expect(described_class.reflect_on_association(:agents).macro).to eq(:has_many) }
    it { expect(described_class.reflect_on_association(:workspaces).macro).to eq(:has_many) }

    it "reaches goals through strategies" do
      reflection = described_class.reflect_on_association(:goals)
      expect(reflection.macro).to eq(:has_many)
      expect(reflection.options[:through]).to eq(:strategies)
    end

    it "reaches projects through goals" do
      reflection = described_class.reflect_on_association(:projects)
      expect(reflection.macro).to eq(:has_many)
      expect(reflection.options[:through]).to eq(:goals)
    end

    it "returns projects descending from its strategies' goals" do
      org = create(:chorus_organization)
      strategy = create(:chorus_strategy, organization: org)
      goal = create(:chorus_goal, strategy: strategy)
      project = create(:chorus_project, goal: goal)
      expect(org.projects).to include(project)
    end
  end

  describe "dependent destruction" do
    it "destroys strategies (and their goals and projects) when destroyed" do
      org = create(:chorus_organization)
      strategy = create(:chorus_strategy, organization: org)
      goal = create(:chorus_goal, strategy: strategy)
      project = create(:chorus_project, goal: goal)

      org.destroy

      expect(Chorus::Strategy.exists?(strategy.id)).to be(false)
      expect(Chorus::Goal.exists?(goal.id)).to be(false)
      expect(Chorus::Project.exists?(project.id)).to be(false)
    end

    it "destroys roles, agents, and workspaces when destroyed" do
      org = create(:chorus_organization)
      role = create(:chorus_role, organization: org)
      agent = create(:chorus_agent, organization: org)
      workspace = create(:chorus_workspace, organization: org)

      org.destroy

      expect(Chorus::Role.exists?(role.id)).to be(false)
      expect(Chorus::Agent.exists?(agent.id)).to be(false)
      expect(Chorus::Workspace.exists?(workspace.id)).to be(false)
    end
  end
end
