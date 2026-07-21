FactoryBot.define do
  factory :chorus_role_skill, class: "Chorus::RoleSkill" do
    role factory: :chorus_role
    skill factory: :chorus_skill
  end
end
