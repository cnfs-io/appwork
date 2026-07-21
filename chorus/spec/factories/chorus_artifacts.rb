FactoryBot.define do
  factory :chorus_artifact, class: "Chorus::Artifact" do
    name { "Artifact #{rand(1000)}" }
    kind { "git_repo" }
    locator { "https://example.com/repo.git" }
  end
end
