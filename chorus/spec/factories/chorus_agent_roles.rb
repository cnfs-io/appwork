FactoryBot.define do
  factory :chorus_agent_role, class: "Chorus::AgentRole" do
    name { "Role #{rand(1000)}" }

    trait :with_requirements do
      after(:create) do |role|
        create(:chorus_skill_requirement, agent_role: role, name: "web-design-guidelines")
        create(:chorus_skill_requirement, agent_role: role, name: "frontend-design")
      end
    end
  end
end
