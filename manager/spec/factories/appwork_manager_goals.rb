FactoryBot.define do
  # No `status`: Goal is a Chorus workable declaring `okf_frontmatter :status`
  # (concept-backed, no column) — see the strategies factory note.
  factory :micro_manager_goal, class: "MicroManager::Goal" do
    strategy factory: :micro_manager_strategy
    name { "Goal #{rand(1000)}" }
  end
end
