require "rails_helper"

RSpec.describe Chorus::Agent, type: :model do
  it "has a valid factory" do
    expect(build(:chorus_agent)).to be_valid
  end

  describe "validations" do
    it "requires a name" do
      agent = build(:chorus_agent, name: nil)
      expect(agent).not_to be_valid
      expect(agent.errors[:name]).to be_present
    end
  end

  describe "associations" do
    # Agent is role-blind and ticket-blind after plan 004: Role left Chorus
    # (IAM provides it) and the ticket backlink lives only on the org side.
    # Holding either here would make Chorus name a departed constant.
    it "does not couple to role" do
      expect(described_class.reflect_on_association(:role)).to be_nil
    end

    it "does not enumerate issues/tickets from the Chorus side" do
      expect(described_class.reflect_on_association(:issues)).to be_nil
      expect(described_class.reflect_on_association(:tickets)).to be_nil
    end
  end
end
