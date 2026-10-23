FactoryBot.define do
  factory :chorus_role, class: "Chorus::Role" do
    name { "Role #{rand(1000)}" }

    trait :with_requirements do
      after(:create) do |role|
        create(:chorus_skill_requirement, role: role, name: "web-design-guidelines")
        create(:chorus_skill_requirement, role: role, name: "frontend-design")
      end
    end
  end
end
