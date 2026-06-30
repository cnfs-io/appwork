FactoryBot.define do
  factory :chorus_project, class: "Chorus::Project" do
    goal factory: :chorus_goal
    name { "Project #{rand(1000)}" }
    status { "active" }
  end
end
