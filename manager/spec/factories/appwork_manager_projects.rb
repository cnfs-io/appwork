FactoryBot.define do
  # No `status` here: Project includes Chorus::Workable, whose `status=` accessor
  # (concept custom_frontmatter) shadows the legacy `status` column. The column is
  # orphaned pending the status/event-sourcing ADR; the factory must not drive it.
  factory :micro_manager_project, class: "MicroManager::Project" do
    goal factory: :micro_manager_goal
    name { "Project #{rand(1000)}" }
  end
end
