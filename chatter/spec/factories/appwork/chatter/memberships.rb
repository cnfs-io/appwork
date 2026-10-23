FactoryBot.define do
  factory :appwork_chatter_membership, class: "Appwork::Chatter::Membership" do
    association :conversation, factory: :appwork_chatter_conversation
    association :participant, factory: :person
    role { :member }
  end
end
