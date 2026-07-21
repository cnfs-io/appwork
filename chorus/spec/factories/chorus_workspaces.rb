FactoryBot.define do
  factory :chorus_workspace, class: "Chorus::Workspace" do
    name { "Workspace #{rand(1000)}" }
    association :role, factory: :chorus_role
  end
end
