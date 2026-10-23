FactoryBot.define do
  factory :appwork_chorus_skill, class: "Appwork::Chorus::Skill" do
    name { "skill-#{rand(1000)}" }
  end
end
