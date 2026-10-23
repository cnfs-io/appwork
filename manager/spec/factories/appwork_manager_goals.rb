FactoryBot.define do
  # No `status`: Goal is a Chorus workable declaring `okf_frontmatter :status`
  # (concept-backed, no column) — see the strategies factory note.
  factory :appwork_manager_goal, class: "Appwork::Manager::Goal" do
    strategy factory: :appwork_manager_strategy
    name { "Goal #{rand(1000)}" }
  end
end
