FactoryBot.define do
  factory :chorus_skill_requirement, class: "Chorus::SkillRequirement" do
    role factory: :chorus_role
    name { "skill-#{rand(1000)}" }
  end
end
