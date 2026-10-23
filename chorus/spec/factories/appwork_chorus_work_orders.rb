FactoryBot.define do
  # A WorkOrder needs a workable (its subject), a workspace (the place), and a role
  # (the requirement). The workable is the dummy host model that includes
  # Appwork::Chorus::Workable — the same stand-in the workable concern specs use.
  factory :appwork_chorus_work_order, class: "Appwork::Chorus::WorkOrder" do
    association :workspace, factory: :appwork_chorus_workspace
    association :role, factory: :appwork_chorus_role
    workable { WorkableDummy.create!(name: "workable-#{rand(1000)}") }
  end
end
