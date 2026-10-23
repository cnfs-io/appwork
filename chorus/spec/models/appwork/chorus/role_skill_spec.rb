require "rails_helper"

# Appwork::Chorus::RoleSkill — the Role <-> Skill join (plan 010 §3). Attribute-free for now;
# a role's skills are unique on the pair (DB-enforced).
RSpec.describe Appwork::Chorus::RoleSkill, type: :model do
  it "has a valid factory" do
    expect(build(:appwork_chorus_role_skill)).to be_valid
  end

  describe "associations" do
    it "belongs to a role" do
      expect(described_class.reflect_on_association(:role).macro).to eq(:belongs_to)
    end

    it "belongs to a skill" do
      expect(described_class.reflect_on_association(:skill).macro).to eq(:belongs_to)
    end
  end

  it "reads back from the Skill side (roles through role_skills)" do
    skill = create(:appwork_chorus_skill)
    role  = create(:appwork_chorus_role)
    create(:appwork_chorus_role_skill, role: role, skill: skill)
    expect(skill.reload.roles).to contain_exactly(role)
  end

  it "is unique per [role, skill]" do
    role  = create(:appwork_chorus_role)
    skill = create(:appwork_chorus_skill)
    create(:appwork_chorus_role_skill, role: role, skill: skill)
    dup = build(:appwork_chorus_role_skill, role: role, skill: skill)
    expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
