FactoryBot.define do
  factory :appwork_chorus_plan, class: "Appwork::Chorus::Plan" do
    association :work_order, factory: :appwork_chorus_work_order
    association :role, factory: :appwork_chorus_role
    name { "plan-#{rand(1000)}" }
  end
end
