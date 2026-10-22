FactoryBot.define do
  # No `status` here: Ticket includes Chorus::Workable, whose `status=` accessor
  # (concept custom_frontmatter) shadows the legacy `status` column. The column is
  # orphaned pending the status/event-sourcing ADR; the factory must not drive it.
  factory :micro_manager_ticket, class: "MicroManager::Ticket" do
    project factory: :micro_manager_project
    title { "Ticket #{rand(1000)}" }
  end
end
