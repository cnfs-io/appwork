FactoryBot.define do
  factory :appwork_chorus_role, class: "Appwork::Chorus::Role" do
    name { "Role #{rand(1000)}" }

    trait :with_requirements do
      after(:create) do |role|
        create(:appwork_chorus_skill_requirement, role: role, name: "web-design-guidelines")
        create(:appwork_chorus_skill_requirement, role: role, name: "frontend-design")
      end
    end
  end
end
