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

    it "requires an organization" do
      expect(build(:chorus_role, organization: nil)).not_to be_valid
    end
  end

  describe "associations" do
    it { expect(described_class.reflect_on_association(:organization).macro).to eq(:belongs_to) }
    it { expect(described_class.reflect_on_association(:agents).macro).to eq(:has_many) }
  end

  describe "dependent nullify" do
    it "nullifies its agents' role when destroyed" do
      org = create(:chorus_organization)
      role = create(:chorus_role, organization: org)
      agent = create(:chorus_agent, organization: org, role: role)

      role.destroy

      expect(agent.reload.role_id).to be_nil
      expect(Chorus::Agent.exists?(agent.id)).to be(true)
    end
  end
end
