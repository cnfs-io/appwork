FactoryBot.define do
  factory :chorus_organization, class: "Chorus::Organization" do
    name { "Organization #{rand(1000)}" }
  end
end
