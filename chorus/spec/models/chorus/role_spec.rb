require "rails_helper"

RSpec.describe Chorus::Role, type: :model do
  it "has a valid factory" do
    expect(build(:chorus_role)).to be_valid
  end

  describe "validations" do
    it "requires a name" do
      role = build(:chorus_role, name: nil)
      expect(role).not_to be_valid
      expect(role.errors[:name]).to be_present
    end
  end

  describe "associations" do
    it { expect(described_class.reflect_on_association(:agents).macro).to eq(:has_many) }
  end

  describe "dependent nullify" do
    xit "nullifies its agents' role when destroyed" do
      role = create(:chorus_role)
      agent = create(:chorus_agent, role: role)

      role.destroy

      expect(agent.reload.role_id).to be_nil
      expect(Chorus::Agent.exists?(agent.id)).to be(true)
    end
  end
end
