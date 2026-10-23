require "rails_helper"

RSpec.describe Chorus::Curation, type: :model do
  describe "validations" do
    it "has a valid factory" do
      expect(build(:chorus_curation)).to be_valid
    end

    it "requires a resource" do
      curation = build(:chorus_curation, resource: nil)
      expect(curation).not_to be_valid
      expect(curation.errors[:resource]).to be_present
    end

    it "rejects a reputation below 0" do
      expect(build(:chorus_curation, reputation: -1)).not_to be_valid
    end

    it "rejects a reputation above 100" do
      expect(build(:chorus_curation, reputation: 101)).not_to be_valid
    end

    it "rejects a present row with a null reputation (nil = unknown is row ABSENCE)" do
      curation = build(:chorus_curation, reputation: nil)
      expect(curation).not_to be_valid
      expect(curation.errors[:reputation]).to be_present
    end
  end

  describe "three-state reputation" do
    it "represents unknown (no verdict) as an absent row" do
      # No Curation row for this skill -> the catalog skill's #curation is nil.
      skill = create(:chorus_catalog_skill, resource: "acme/repo", skill_name: "a")
      expect(skill.curation).to be_nil
    end

    it "represents known-bad as a present row with reputation 0 (NOT collapsed with nil)" do
      curation = create(:chorus_curation, :known_bad)
      expect(curation.reputation).to eq(0)
      expect(curation).to be_persisted
    end

    it "represents graded quality as reputation 1..100" do
      expect(build(:chorus_curation, reputation: 1)).to be_valid
      expect(build(:chorus_curation, reputation: 100)).to be_valid
    end
  end

  describe "the natural key [resource, skill_name]" do
    it "is unique" do
      create(:chorus_curation, resource: "acme/repo", skill_name: "a")
      dup = build(:chorus_curation, resource: "acme/repo", skill_name: "a")
      expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "#catalog_skill (resolved on the natural key)" do
    it "returns nil when this tenant has not mirrored the skill locally yet" do
      curation = create(:chorus_curation, resource: "acme/repo", skill_name: "a")
      expect(curation.catalog_skill).to be_nil
    end

    it "finds the mirrored CatalogSkill on [resource, skill_name]" do
      skill = create(:chorus_catalog_skill, resource: "acme/repo", skill_name: "a")
      curation = create(:chorus_curation, resource: "acme/repo", skill_name: "a")
      expect(curation.catalog_skill).to eq(skill)
    end
  end

  describe "YamlSerializable round-trip on the natural key" do
    it "dumps a set of rows and reloads them with identity preserved" do
      create(:chorus_curation, resource: "acme/one", skill_name: "a", reputation: 10)
      create(:chorus_curation, resource: "acme/two", skill_name: nil, reputation: 0)
      path = File.join(Dir.tmpdir, "curations-#{SecureRandom.hex(4)}.yml")

      described_class.dump_to_yaml(path)
      described_class.delete_all
      count = described_class.load_from_yaml(path)

      expect(count).to eq(2)
      expect(described_class.find_by(resource: "acme/one", skill_name: "a").reputation).to eq(10)
      expect(described_class.find_by(resource: "acme/two", skill_name: nil).reputation).to eq(0)
    ensure
      File.delete(path) if path && File.exist?(path)
    end
  end
end
