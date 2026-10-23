FactoryBot.define do
  factory :appwork_chatter_message, class: "Appwork::Chatter::Message" do
    association :conversation, factory: :appwork_chatter_conversation
    association :sender, factory: :person
    sequence(:content) { |n| "Message body #{n}" }
  end
end
