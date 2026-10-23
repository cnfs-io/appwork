FactoryBot.define do
  # No `status` here: Ticket includes Appwork::Chorus::Workable, whose `status=` accessor
  # (concept custom_frontmatter) shadows the legacy `status` column. The column is
  # orphaned pending the status/event-sourcing ADR; the factory must not drive it.
  factory :appwork_manager_ticket, class: "Appwork::Manager::Ticket" do
    project factory: :appwork_manager_project
    title { "Ticket #{rand(1000)}" }
  end
end
