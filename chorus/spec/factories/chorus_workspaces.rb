FactoryBot.define do
  factory :chorus_workspace, class: "Chorus::Workspace" do
    name { "Workspace #{rand(1000)}" }
  end
end
