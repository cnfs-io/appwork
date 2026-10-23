require "rails_helper"

module Appwork
  module Chatter
    RSpec.describe Membership, type: :model do
      it "forbids duplicate participant memberships in a conversation" do
        person = create(:person)
        conversation = create(:appwork_chatter_conversation)
        create(:appwork_chatter_membership, conversation: conversation, participant: person)

        duplicate = build(:appwork_chatter_membership, conversation: conversation, participant: person)

        expect(duplicate).not_to be_valid
      end

      it "allows the same participant in different conversations" do
        person = create(:person)
        create(:appwork_chatter_membership, participant: person)

        other = build(:appwork_chatter_membership, participant: person)

        expect(other).to be_valid
      end

      it "treats different participant types with the same id as distinct" do
        conversation = create(:appwork_chatter_conversation)
        person = create(:person)
        agent = create(:agent)

        create(:appwork_chatter_membership, conversation: conversation, participant: person)
        other = build(:appwork_chatter_membership, conversation: conversation, participant: agent)

        expect(other).to be_valid
      end
    end
  end
end
