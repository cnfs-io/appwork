FactoryBot.define do
  factory :chorus_result, class: "Chorus::Result" do
    workspace factory: :chorus_workspace
  end
end
