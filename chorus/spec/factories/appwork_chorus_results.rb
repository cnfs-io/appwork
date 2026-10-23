FactoryBot.define do
  factory :appwork_chorus_result, class: "Appwork::Chorus::Result" do
    association :resultable, factory: :appwork_chorus_work_order
  end
end
