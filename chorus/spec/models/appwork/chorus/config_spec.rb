require "rails_helper"

RSpec.describe Appwork::Chorus::Config do
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

  describe "execution-mode defaults (007 §8)" do
    it "defaults agents_live to true (live by default)" do
      described_class.reset_instance!
      expect(described_class.agents_live).to be(true)
    end

    it "defaults skills_live to true (live by default)" do
      described_class.reset_instance!
      expect(described_class.skills_live).to be(true)
    end
  end

  describe "execution-environment defaults (009 §6)" do
    it "defaults workspace_root to ~/.chorus/workspaces (outside any repo)" do
      described_class.reset_instance!
      expect(described_class.workspace_root).to eq("~/.chorus/workspaces")
    end

    it "defaults skill_copy to true (copy is the safe choice everywhere)" do
      described_class.reset_instance!
      expect(described_class.skill_copy).to be(true)
    end
  end

  describe "execution-environment resolution from ENV" do
    around do |example|
      ENV["APPWORK_CHORUS_WORKSPACE_ROOT"] = "/var/chorus/ws"
      ENV["APPWORK_CHORUS_SKILL_COPY"] = "false"
      described_class.reset_instance!
      example.run
    ensure
      ENV.delete("APPWORK_CHORUS_WORKSPACE_ROOT")
      ENV.delete("APPWORK_CHORUS_SKILL_COPY")
      described_class.reset_instance!
    end

    it "reads APPWORK_CHORUS_WORKSPACE_ROOT" do
      expect(described_class.workspace_root).to eq("/var/chorus/ws")
    end

    it "coerces APPWORK_CHORUS_SKILL_COPY to a boolean" do
      expect(described_class.skill_copy).to be(false)
    end
  end

  describe "resolution from ENV (the family precedence)" do
    around do |example|
      ENV["APPWORK_CHORUS_CURATION_ENABLED"] = "false"
      ENV["APPWORK_CHORUS_REPUTATION_THRESHOLD"] = "80"
      described_class.reset_instance!
      example.run
    ensure
      ENV.delete("APPWORK_CHORUS_CURATION_ENABLED")
      ENV.delete("APPWORK_CHORUS_REPUTATION_THRESHOLD")
      described_class.reset_instance!
    end

    it "coerces APPWORK_CHORUS_CURATION_ENABLED to a boolean" do
      expect(described_class.curation_enabled).to be(false)
    end

    it "coerces APPWORK_CHORUS_REPUTATION_THRESHOLD to an integer" do
      expect(described_class.reputation_threshold).to eq(80)
    end
  end

  describe "execution-mode resolution from ENV (dry override)" do
    around do |example|
      ENV["APPWORK_CHORUS_AGENTS_LIVE"] = "false"
      ENV["APPWORK_CHORUS_SKILLS_LIVE"] = "false"
      described_class.reset_instance!
      example.run
    ensure
      ENV.delete("APPWORK_CHORUS_AGENTS_LIVE")
      ENV.delete("APPWORK_CHORUS_SKILLS_LIVE")
      described_class.reset_instance!
    end

    it "coerces APPWORK_CHORUS_AGENTS_LIVE to a boolean" do
      expect(described_class.agents_live).to be(false)
    end

    it "coerces APPWORK_CHORUS_SKILLS_LIVE to a boolean" do
      expect(described_class.skills_live).to be(false)
    end
  end
end
