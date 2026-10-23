FactoryBot.define do
  factory :chorus_skill, class: "Chorus::Skill" do
    name { "skill-#{rand(1000)}" }
  end
end
