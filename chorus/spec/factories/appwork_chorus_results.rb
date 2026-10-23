FactoryBot.define do
  factory :chorus_result, class: "Chorus::Result" do
    association :resultable, factory: :chorus_work_order
  end
end
