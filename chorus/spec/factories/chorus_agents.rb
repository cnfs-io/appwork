FactoryBot.define do
  factory :chorus_agent, class: "Chorus::Agent" do
    name { "Agent #{rand(1000)}" }
    # kind { "human" }

    trait :with_claude_code_profile do
      association :agent_profile, factory: :chorus_agent_profile_claude_code
    end
  end
end
