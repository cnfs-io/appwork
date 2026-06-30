require "rails_helper"

RSpec.describe Chorus::Strategy, type: :model do
  it "has a valid factory" do
    expect(build(:chorus_strategy)).to be_valid
  end

  describe "validations" do
    it "requires a name" do
      strategy = build(:chorus_strategy, name: nil)
      expect(strategy).not_to be_valid
      expect(strategy.errors[:name]).to be_present
    end

    it "requires an organization" do
      expect(build(:chorus_strategy, organization: nil)).not_to be_valid
    end
  end

  describe "associations" do
    it { expect(described_class.reflect_on_association(:organization).macro).to eq(:belongs_to) }
    it { expect(described_class.reflect_on_association(:goals).macro).to eq(:has_many) }
  end

  describe "dependent destruction" do
    it "destroys its goals when destroyed" do
      strategy = create(:chorus_strategy)
      goal = create(:chorus_goal, strategy: strategy)

      strategy.destroy

      expect(Chorus::Goal.exists?(goal.id)).to be(false)
    end
  end
end
