FactoryBot.define do
  factory :chorus_goal, class: "Chorus::Goal" do
    strategy factory: :chorus_strategy
    name { "Goal #{rand(1000)}" }
    status { "active" }
  end
end
