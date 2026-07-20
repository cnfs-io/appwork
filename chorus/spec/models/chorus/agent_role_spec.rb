require "rails_helper"

# Chorus::AgentRole — a CAPABILITY LOADOUT (skills-by-name + OKF concept + view_ports),
# catalog-naive and org-naive. Distinct from the departed org-position Role (004).
RSpec.describe Chorus::AgentRole, type: :model do
  it "has a valid factory" do
    expect(build(:chorus_agent_role)).to be_valid
  end

  describe "validations" do
    it "requires a name" do
      role = build(:chorus_agent_role, name: nil)
      expect(role).not_to be_valid
      expect(role.errors[:name]).to be_present
    end
  end

  describe "the two OKF bindings (self-definition + domain windows)" do
    it "has_one_okf :concept — the role's own charter" do
      reflection = described_class.reflect_on_association(:concept)
      expect(reflection.macro).to eq(:has_one)
      expect(reflection.options[:as]).to eq(:owner)
      expect(reflection.klass).to eq(CnfsOkf::Concept)
    end

    it "has_many_okf :view_ports — the role's domain-knowledge windows" do
      reflection = described_class.reflect_on_association(:view_ports)
      expect(reflection.macro).to eq(:has_many)
      expect(reflection.options[:as]).to eq(:owner)
      expect(reflection.klass).to eq(CnfsOkf::ViewPort)
    end
  end

  describe "skills by stable name (NOT a catalog FK)" do
    it "has_many :skill_requirements" do
      expect(described_class.reflect_on_association(:skill_requirements).macro).to eq(:has_many)
    end

    it "requirements are name-only — no catalog FK on the role" do
      expect(described_class.reflect_on_association(:catalog_skills)).to be_nil
      expect(described_class.reflect_on_association(:catalog_skill)).to be_nil
    end

    it "destroys its requirements with it" do
      role = create(:chorus_agent_role, :with_requirements)
      expect { role.destroy }.to change(Chorus::SkillRequirement, :count).by(-2)
    end
  end

  describe "org- and source-naive (boundary cleanliness)" do
    it "does not belong to a source (domain knowledge is OKF addressing, not a source FK)" do
      expect(described_class.reflect_on_association(:source)).to be_nil
    end

    it "carries no organization FK" do
      expect(described_class.reflect_on_association(:organization)).to be_nil
      expect(described_class.column_names).not_to include("organization_id")
    end
  end
end
