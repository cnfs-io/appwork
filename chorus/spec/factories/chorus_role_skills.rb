FactoryBot.define do
  factory :chorus_role_skill, class: "Chorus::RoleSkill" do
    agent_role factory: :chorus_agent_role
    skill factory: :chorus_skill
  end
end
