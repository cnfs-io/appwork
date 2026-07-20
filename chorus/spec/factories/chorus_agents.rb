FactoryBot.define do
  factory :chorus_agent, class: "Chorus::Agent" do
    name { "Agent #{rand(1000)}" }
    # kind { "human" }

    trait :with_claude_code_adapter do
      association :agent_adapter, factory: :chorus_agent_adapter_claude_code
    end
  end
end
