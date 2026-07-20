require "rails_helper"

# Chorus::RoleSkill — the AgentRole <-> Skill join (plan 010 §3). Attribute-free
# for now; a role's skills are unique on the pair (DB-enforced).
RSpec.describe Chorus::RoleSkill, type: :model do
  it "has a valid factory" do
    expect(build(:chorus_role_skill)).to be_valid
  end

  describe "associations" do
    it "belongs to an agent_role" do
      expect(described_class.reflect_on_association(:agent_role).macro).to eq(:belongs_to)
    end

    it "belongs to a skill" do
      expect(described_class.reflect_on_association(:skill).macro).to eq(:belongs_to)
    end
  end

  it "reads back from the Skill side (agent_roles through role_skills)" do
    skill = create(:chorus_skill)
    role  = create(:chorus_agent_role)
    create(:chorus_role_skill, agent_role: role, skill: skill)
    expect(skill.reload.agent_roles).to contain_exactly(role)
  end

  it "is unique per [agent_role, skill]" do
    role  = create(:chorus_agent_role)
    skill = create(:chorus_skill)
    create(:chorus_role_skill, agent_role: role, skill: skill)
    dup = build(:chorus_role_skill, agent_role: role, skill: skill)
    expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
