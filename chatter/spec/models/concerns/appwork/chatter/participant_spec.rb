require "rails_helper"

module Appwork
  module Chatter
    RSpec.describe Participant, type: :model do
      shared_examples "a chatter participant" do |factory|
        let(:participant) { create(factory) }

        it "exposes conversations through memberships" do
          conversation = create(:appwork_chatter_conversation)
          create(:appwork_chatter_membership, conversation: conversation, participant: participant)

          expect(participant.conversations).to include(conversation)
        end

        it "exposes sent messages polymorphically" do
          conversation = create(:appwork_chatter_conversation)
          create(:appwork_chatter_membership, conversation: conversation, participant: participant)
          message = create(:appwork_chatter_message, conversation: conversation, sender: participant)

          expect(participant.sent_messages).to include(message)
        end

        it "provides a display name" do
          expect(participant.chatter_display_name).to be_present
        end
      end

      it_behaves_like "a chatter participant", :person
      it_behaves_like "a chatter participant", :agent

      it "lets host models override chatter_display_name" do
        person = create(:person, name: "Ada")
        expect(person.chatter_display_name).to eq("Ada")
      end
    end
  end
end
