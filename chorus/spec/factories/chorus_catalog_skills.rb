FactoryBot.define do
  # A mirrored upstream skill. Randomized natural key satisfies the unique
  # [resource, skill_name] index.
  factory :chorus_catalog_skill, class: "Chorus::CatalogSkill" do
    resource { "acme/agent-skills-#{rand(10_000)}" }
    skill_name { "skill-#{rand(10_000)}" }
    description { "A mirrored upstream skill." }
    install_count { 1_234 }

    # A whole-repo entry (no individual skill).
    trait :whole_repo do
      skill_name { nil }
    end
  end
end
