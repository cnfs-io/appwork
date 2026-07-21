require "rails_helper"

# Chorus::Result — ONE row per invocation (plan 011 §8), polymorphic over its
# resultable (a WorkOrder or Plan). A rewrite, not a rename: the old
# ActiveModel::Errors-shaped accumulator is gone. A retry is a SECOND Result, so
# "did this succeed?" is a question about `resultable.results` collectively.
RSpec.describe Chorus::Result, type: :model do
  it "has a valid factory" do
    expect(build(:chorus_result)).to be_valid
  end

  describe "associations" do
    it "belongs to a polymorphic resultable" do
      reflection = described_class.reflect_on_association(:resultable)
      expect(reflection.macro).to eq(:belongs_to)
      expect(reflection.options[:polymorphic]).to be(true)
    end

    it "has many artifacts (the things a run produced), nullify on destroy" do
      reflection = described_class.reflect_on_association(:artifacts)
      expect(reflection.macro).to eq(:has_many)
      expect(reflection.options[:dependent]).to eq(:nullify)
    end

    # The old accumulator interface is gone (§8).
    it "no longer exposes the ActiveModel::Errors-shaped surface" do
      result = build(:chorus_result)
      expect(result).not_to respond_to(:add)
      expect(result).not_to respond_to(:merge)
      expect(result).not_to respond_to(:full_messages)
      expect(result).not_to respond_to(:record_argv)
    end
  end

  describe "many per resultable (attempt history)" do
    it "records each run as its own row, ordered by creation" do
      work_order = create(:chorus_work_order)
      first  = create(:chorus_result, resultable: work_order, success: false)
      second = create(:chorus_result, resultable: work_order, success: true)

      expect(work_order.reload.results.order(:id)).to eq([ first, second ])
    end

    it "a Plan is equally a resultable" do
      plan = create(:chorus_plan)
      result = create(:chorus_result, resultable: plan)
      expect(plan.reload.results).to contain_exactly(result)
    end
  end

  describe "produced artifacts" do
    it "an artifact points back at the result that produced it" do
      result = create(:chorus_result)
      artifact = create(:chorus_artifact, result: result)
      expect(artifact.reload.result).to eq(result)
      expect(result.reload.artifacts).to contain_exactly(artifact)
    end
  end

  describe "the plain diagnostics bags" do
    it "defaults argv and messages to empty json, round-tripping intact" do
      result = create(:chorus_result, argv: [ "claude", "-p", "x" ], messages: { "note" => "hi" })
      reloaded = described_class.find(result.id)
      expect(reloaded.argv).to eq([ "claude", "-p", "x" ])
      expect(reloaded.messages).to eq("note" => "hi")
    end

    it "records cost/usage/session columns as plain attributes" do
      result = create(:chorus_result,
                      external_session_id: "sess-abc", cost_usd: 0.0123,
                      duration_ms: 4567, num_turns: 3, is_error: false)
      reloaded = described_class.find(result.id)
      expect(reloaded.external_session_id).to eq("sess-abc")
      expect(reloaded.cost_usd).to eq(0.0123)
      expect(reloaded.num_turns).to eq(3)
    end
  end
end
