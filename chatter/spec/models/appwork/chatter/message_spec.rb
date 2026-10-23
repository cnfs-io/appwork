require "rails_helper"

module Appwork
  module Chatter
    RSpec.describe Message, type: :model do
      it "requires content" do
        message = build(:appwork_chatter_message, content: nil)
        expect(message).not_to be_valid
      end

      it "orders by creation time by default" do
        conversation = create(:appwork_chatter_conversation)
        older = create(:appwork_chatter_message, conversation: conversation, created_at: 2.hours.ago)
        newer = create(:appwork_chatter_message, conversation: conversation, created_at: 1.hour.ago)

        expect(conversation.messages.to_a).to eq([ older, newer ])
      end
    end
  end
end
