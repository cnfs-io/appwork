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

    it "is valid without a role (role is optional)" do
      expect(build(:chorus_agent, role: nil)).to be_valid
    end
  end

  describe "associations" do
    it { expect(described_class.reflect_on_association(:issues).macro).to eq(:has_many) }

    it "marks role as optional" do
      expect(described_class.reflect_on_association(:role).options[:optional]).to be(true)
    end
  end

  describe "dependent nullify" do
    xit "nullifies its issues' agent when destroyed" do
      agent = create(:chorus_agent)
      issue = create(:chorus_issue, agent: agent)

      agent.destroy

      expect(issue.reload.agent_id).to be_nil
      expect(Chorus::Issue.exists?(issue.id)).to be(true)
    end
  end
end
