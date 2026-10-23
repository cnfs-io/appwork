FactoryBot.define do
  factory :appwork_chorus_artifact, class: "Appwork::Chorus::Artifact" do
    name { "Artifact #{rand(1000)}" }
    kind { "git_repo" }
    locator { "https://example.com/repo.git" }
  end
end
