require "rails_helper"

# Chorus::Result — AR-backed, ActiveModel::Errors-shaped (§5). The interface is what
# matters (keyed messages that merge; empty?/success?/full_messages); the backing is
# a chorus_results row so an evaluator can later append to the SAME record.
RSpec.describe Chorus::Result, type: :model do
  describe "associations" do
    it "belongs to an artifact (optional) and a workspace (optional)" do
      expect(described_class.reflect_on_association(:artifact).options[:optional]).to be(true)
      expect(described_class.reflect_on_association(:workspace).options[:optional]).to be(true)
    end

    # 007 builds Result review-READY, not reviewed — the Review model lands in 008.
    it "does NOT declare has_many :reviews (would dangle without chorus_reviews)" do
      expect(described_class.reflect_on_association(:reviews)).to be_nil
    end
  end

  describe "the ActiveModel::Errors-shaped surface" do
    subject(:result) { build(:chorus_result) }

    it "starts empty" do
      expect(result).to be_empty
      expect(result.full_messages).to eq([])
    end

    it "accumulates keyed messages" do
      result.add(:equip, "web-design-guidelines mounted")
      result.add(:equip, "frontend-design mounted")
      result.add(:invoke, "claude -p issued")

      expect(result).not_to be_empty
      expect(result.full_messages).to contain_exactly(
        "equip web-design-guidelines mounted",
        "equip frontend-design mounted",
        "invoke claude -p issued"
      )
    end

    it "is chainable (returns self from #add)" do
      expect(result.add(:a, "one")).to be(result)
    end
  end

  # The merge path is the evaluator-readiness assertion: several contributors
  # compose into one Result.
  describe "#merge (multiple contributors compose)" do
    it "merges another Result's messages in" do
      a = build(:chorus_result).add(:equip, "equipped")
      b = build(:chorus_result).add(:invoke, "invoked").add(:invoke, "captured")

      a.merge(b)

      expect(a.full_messages).to contain_exactly(
        "equip equipped", "invoke invoked", "invoke captured"
      )
    end

    it "merges a raw keyed bag in" do
      result = build(:chorus_result).add(:equip, "equipped")
      result.merge("review" => [ "a11y ok", "markup ok" ])

      expect(result.full_messages).to include("review a11y ok", "review markup ok", "equip equipped")
    end
  end

  describe "#success? (gates delivery the way valid? gates save)" do
    it "reads the recorded outcome when set" do
      expect(build(:chorus_result, success: true).success?).to be(true)
      expect(build(:chorus_result, success: false).success?).to be(false)
    end

    it "falls back to empty? when the outcome is unset" do
      result = build(:chorus_result, success: nil)
      expect(result.success?).to be(true)
      result.add(:error, "boom")
      expect(result.success?).to be(false)
    end
  end

  describe "argv recording (dry-run inspectability, §8)" do
    it "records phase-tagged argv and reads it back per phase" do
      result = build(:chorus_result)
      result.record_argv(:equip, [ "npx", "skills", "add", "vercel-labs/agent-skills" ])
      result.record_argv(:invoke, [ "claude", "-p", "task" ])

      expect(result.argv_for(:equip)).to eq([ [ "npx", "skills", "add", "vercel-labs/agent-skills" ] ])
      expect(result.argv_for(:invoke)).to eq([ [ "claude", "-p", "task" ] ])
    end
  end

  describe "persistence round-trip" do
    it "persists messages and argv and reloads them intact" do
      result = create(:chorus_result)
      result.add(:equip, "mounted").record_argv(:invoke, [ "claude", "-p", "task" ])
      result.save!

      reloaded = described_class.find(result.id)
      expect(reloaded.full_messages).to eq([ "equip mounted" ])
      expect(reloaded.argv_for(:invoke)).to eq([ [ "claude", "-p", "task" ] ])
    end
  end
end
