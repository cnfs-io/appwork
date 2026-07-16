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
    # Settled in 007 (001's open FK): an Agent binds to one AgentProfile (its
    # runtime), optionally — invocation resolves the profile through this.
    it "belongs to an agent_profile (optional)" do
      reflection = described_class.reflect_on_association(:agent_profile)
      expect(reflection).to be_present
      expect(reflection.macro).to eq(:belongs_to)
      expect(reflection.options[:optional]).to be(true)
    end

    it "round-trips its profile" do
      profile = create(:chorus_agent_profile_claude_code)
      agent = create(:chorus_agent, agent_profile: profile)
      expect(agent.reload.agent_profile).to eq(profile)
    end

    # Agent is role-blind and ticket-blind after plan 004: the org-position Role
    # left Chorus (IAM provides it) and the ticket backlink lives only on the org
    # side. Holding either here would make Chorus name a departed constant. (The
    # 007 capability Role is a separate concept and does NOT FK from Agent.)
    it "does not couple to role" do
      expect(described_class.reflect_on_association(:role)).to be_nil
    end

    it "does not enumerate issues/tickets from the Chorus side" do
      expect(described_class.reflect_on_association(:issues)).to be_nil
      expect(described_class.reflect_on_association(:tickets)).to be_nil
    end
  end
end
