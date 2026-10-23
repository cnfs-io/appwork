FactoryBot.define do
  # No `status` here: Project includes Appwork::Chorus::Workable, whose `status=` accessor
  # (concept custom_frontmatter) shadows the legacy `status` column. The column is
  # orphaned pending the status/event-sourcing ADR; the factory must not drive it.
  factory :appwork_manager_project, class: "Appwork::Manager::Project" do
    goal factory: :appwork_manager_goal
    name { "Project #{rand(1000)}" }
  end
end
