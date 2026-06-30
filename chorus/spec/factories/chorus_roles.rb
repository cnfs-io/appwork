FactoryBot.define do
  factory :chorus_role, class: "Chorus::Role" do
    organization factory: :chorus_organization
    name { "Role #{rand(1000)}" }
  end
end
