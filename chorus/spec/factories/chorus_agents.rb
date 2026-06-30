FactoryBot.define do
  factory :chorus_agent, class: "Chorus::Agent" do
    organization factory: :chorus_organization
    name { "Agent #{rand(1000)}" }
    kind { "human" }
  end
end
