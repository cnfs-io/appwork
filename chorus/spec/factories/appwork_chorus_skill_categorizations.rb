FactoryBot.define do
  factory :appwork_chorus_skill_categorization, class: "Appwork::Chorus::SkillCategorization" do
    association :catalog_skill, factory: :appwork_chorus_catalog_skill
    association :taxonomy, factory: :appwork_chorus_taxonomy
  end
end
