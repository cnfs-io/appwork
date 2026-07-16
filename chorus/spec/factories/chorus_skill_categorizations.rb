FactoryBot.define do
  factory :chorus_skill_categorization, class: "Chorus::SkillCategorization" do
    association :catalog_skill, factory: :chorus_catalog_skill
    association :taxonomy, factory: :chorus_taxonomy
  end
end
