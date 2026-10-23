FactoryBot.define do
  # No `status`: Strategy is a Chorus workable declaring `okf_frontmatter :status`,
  # whose accessor writes the OKF concept's custom_frontmatter (there is no status
  # column, and the accessor would raise against a nil concept). Status is set in
  # specs via a claimed concept, not the factory.
  factory :appwork_manager_strategy, class: "Appwork::Manager::Strategy" do
    name { "Strategy #{rand(1000)}" }
  end
end
