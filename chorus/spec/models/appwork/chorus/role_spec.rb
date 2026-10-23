require "rails_helper"

# Chorus::Role — the requirement a piece of work carries (plan 011 §1): a charter
# (has_one_okf :concept) and skills through the RoleSkill join. The former AgentRole,
# renamed now that IAM's Role narrowed to authorization and no collision remains.
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

  describe "the charter (its own OKF self-definition)" do
    it "has_one_okf :concept" do
      reflection = described_class.reflect_on_association(:concept)
      expect(reflection.macro).to eq(:has_one)
      expect(reflection.options[:as]).to eq(:owner)
      expect(reflection.klass).to eq(CnfsOkf::Concept)
    end

    # Scaled back in 010 §2: view_ports was speculative structure with no consumer.
    it "no longer carries view_ports" do
      expect(described_class.reflect_on_association(:view_ports)).to be_nil
    end
  end

  describe "skills through the RoleSkill join (§3)" do
    it "has_many :skills, through: :role_skills" do
      reflection = described_class.reflect_on_association(:skills)
      expect(reflection.macro).to eq(:has_many)
      expect(reflection.options[:through]).to eq(:role_skills)
    end

    it "equips a skill and reads it back" do
      role  = create(:chorus_role)
      skill = create(:chorus_skill)
      role.skills << skill
      expect(role.reload.skills).to contain_exactly(skill)
    end

    it "destroys its role_skills with it (join rows, not the skills)" do
      role  = create(:chorus_role)
      skill = create(:chorus_skill)
      role.skills << skill

      expect { role.destroy }.to change(Chorus::RoleSkill, :count).by(-1)
      expect(Chorus::Skill.exists?(skill.id)).to be(true)
    end

    # No longer reaches SkillRequirement (010 §2 dropped the association; that join
    # is parked, keyed directly by role).
    it "does not couple to skill_requirements" do
      expect(described_class.reflect_on_association(:skill_requirements)).to be_nil
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
