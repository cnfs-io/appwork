FactoryBot.define do
  factory :chorus_workspace, class: "Chorus::Workspace" do
    organization factory: :chorus_organization
    name { "Workspace #{rand(1000)}" }
  end
end
