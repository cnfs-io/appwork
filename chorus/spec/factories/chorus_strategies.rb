FactoryBot.define do
  factory :chorus_strategy, class: "Chorus::Strategy" do
    name { "Strategy #{rand(1000)}" }
    status { "active" }
  end
end
