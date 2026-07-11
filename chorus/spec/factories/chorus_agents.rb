FactoryBot.define do
  factory :chorus_agent, class: "Chorus::Agent" do
    name { "Agent #{rand(1000)}" }
    # kind { "human" }
  end
end
