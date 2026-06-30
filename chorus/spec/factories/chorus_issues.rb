FactoryBot.define do
  factory :chorus_issue, class: "Chorus::Issue" do
    project factory: :chorus_project
    title { "Issue #{rand(1000)}" }
    status { "open" }
  end
end
