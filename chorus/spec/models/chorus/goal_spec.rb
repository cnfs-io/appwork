require "rails_helper"

RSpec.describe Chorus::Goal, type: :model do
  it "has a valid factory" do
    expect(build(:chorus_goal)).to be_valid
  end

  describe "validations" do
    it "requires a name" do
      goal = build(:chorus_goal, name: nil)
      expect(goal).not_to be_valid
      expect(goal.errors[:name]).to be_present
    end

    it "requires a strategy" do
      expect(build(:chorus_goal, strategy: nil)).not_to be_valid
    end
  end

  describe "associations" do
    it { expect(described_class.reflect_on_association(:strategy).macro).to eq(:belongs_to) }
    it { expect(described_class.reflect_on_association(:projects).macro).to eq(:has_many) }

    it "reaches organization through strategy" do
      reflection = described_class.reflect_on_association(:organization)
      expect(reflection.macro).to eq(:has_one)
      expect(reflection.options[:through]).to eq(:strategy)
    end

    it "returns the strategy's organization" do
      org = create(:chorus_organization)
      strategy = create(:chorus_strategy, organization: org)
      goal = create(:chorus_goal, strategy: strategy)
      expect(goal.organization).to eq(org)
    end
  end

  describe "dependent destruction" do
    it "destroys its projects when destroyed" do
      goal = create(:chorus_goal)
      project = create(:chorus_project, goal: goal)

      goal.destroy

      expect(Chorus::Project.exists?(project.id)).to be(false)
    end
  end
end
