FactoryBot.define do
  factory :chorus_role, class: "Chorus::Role" do
    name { "Role #{rand(1000)}" }
  end
end
