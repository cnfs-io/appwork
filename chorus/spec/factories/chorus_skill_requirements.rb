FactoryBot.define do
  factory :chorus_skill_requirement, class: "Chorus::SkillRequirement" do
    agent_role factory: :chorus_agent_role
    name { "skill-#{rand(1000)}" }
  end
end
