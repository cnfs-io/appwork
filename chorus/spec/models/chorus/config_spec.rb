require "rails_helper"

RSpec.describe Chorus::Config do
  after { described_class.reset_instance! }

  describe "curation posture defaults" do
    it "defaults curation_enabled to true (curated by default)" do
      described_class.reset_instance!
      expect(described_class.curation_enabled).to be(true)
    end

    it "defaults reputation_threshold to 50 (a modest non-zero bar)" do
      described_class.reset_instance!
      expect(described_class.reputation_threshold).to eq(50)
    end
  end

  describe "resolution from ENV (the family precedence)" do
    around do |example|
      ENV["CHORUS_CURATION_ENABLED"] = "false"
      ENV["CHORUS_REPUTATION_THRESHOLD"] = "80"
      described_class.reset_instance!
      example.run
    ensure
      ENV.delete("CHORUS_CURATION_ENABLED")
      ENV.delete("CHORUS_REPUTATION_THRESHOLD")
      described_class.reset_instance!
    end

    it "coerces CHORUS_CURATION_ENABLED to a boolean" do
      expect(described_class.curation_enabled).to be(false)
    end

    it "coerces CHORUS_REPUTATION_THRESHOLD to an integer" do
      expect(described_class.reputation_threshold).to eq(80)
    end
  end
end
