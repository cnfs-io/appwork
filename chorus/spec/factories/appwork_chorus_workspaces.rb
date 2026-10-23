FactoryBot.define do
  factory :appwork_chorus_workspace, class: "Appwork::Chorus::Workspace" do
    name { "Workspace #{rand(1000)}" }
    association :role, factory: :appwork_chorus_role
  end
end
