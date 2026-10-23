FactoryBot.define do
  factory :appwork_chatter_conversation, class: "Appwork::Chatter::Conversation" do
    kind { :group }
    sequence(:name) { |n| "Group #{n}" }

    trait :direct do
      kind { :direct }
      name { nil }
    end
  end
end
