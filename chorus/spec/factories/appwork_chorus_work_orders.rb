FactoryBot.define do
  # A WorkOrder needs a workable (its subject), a workspace (the place), and a role
  # (the requirement). The workable is the dummy host model that includes
  # Chorus::Workable — the same stand-in the workable concern specs use.
  factory :chorus_work_order, class: "Chorus::WorkOrder" do
    association :workspace, factory: :chorus_workspace
    association :role, factory: :chorus_role
    workable { WorkableDummy.create!(name: "workable-#{rand(1000)}") }
  end
end
