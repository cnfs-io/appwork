FactoryBot.define do
  factory :appwork_chorus_skill_requirement, class: "Appwork::Chorus::SkillRequirement" do
    role factory: :appwork_chorus_role
    name { "skill-#{rand(1000)}" }
  end
end
