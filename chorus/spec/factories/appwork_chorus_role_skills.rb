FactoryBot.define do
  factory :appwork_chorus_role_skill, class: "Appwork::Chorus::RoleSkill" do
    role factory: :appwork_chorus_role
    skill factory: :appwork_chorus_skill
  end
end
