FactoryBot.define do
  factory :chorus_plan, class: "Chorus::Plan" do
    workspace factory: :chorus_workspace
    agent factory: :chorus_agent
    name { "plan-#{rand(1000)}" }
  end
end
