FactoryBot.define do
  factory :chorus_plan, class: "Chorus::Plan" do
    association :work_order, factory: :chorus_work_order
    association :role, factory: :chorus_role
    name { "plan-#{rand(1000)}" }
  end
end
