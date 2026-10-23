FactoryBot.define do
  # chorus.org's verdict. Randomized natural key satisfies the unique
  # [resource, skill_name] index. A PRESENT row always carries a 0..100 score;
  # the "unknown/no verdict" state is row ABSENCE, not a factory trait.
  factory :appwork_chorus_curation, class: "Appwork::Chorus::Curation" do
    resource { "acme/agent-skills-#{rand(10_000)}" }
    skill_name { "skill-#{rand(10_000)}" }
    reputation { 75 }

    # chorus.org reviewed it and it is trash/dangerous — the bottom of the scale,
    # NOT a hard block. Distinct from an absent row (unknown).
    trait :known_bad do
      reputation { 0 }
    end
  end
end
