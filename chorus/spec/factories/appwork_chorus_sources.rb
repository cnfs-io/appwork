FactoryBot.define do
  # Base Source is abstract in practice (validates :type present); build concrete
  # kinds via the subclass factories below.
  factory :appwork_chorus_source_git, class: "Appwork::Chorus::Source::Git" do
    resource { "git@github.com:acme/repo-#{rand(1000)}.git" }
    path { "/tmp/chorus/sources/repo-#{rand(1000)}" }

    trait :on_branch do
      branch { "main" }
    end

    trait :synced do
      ref { SecureRandom.hex(20) }
      synced_at { Time.current }
    end
  end
end
