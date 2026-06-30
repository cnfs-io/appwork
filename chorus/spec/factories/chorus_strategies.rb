FactoryBot.define do
  factory :chorus_strategy, class: "Chorus::Strategy" do
    organization factory: :chorus_organization
    name { "Strategy #{rand(1000)}" }
    status { "active" }
  end
end
