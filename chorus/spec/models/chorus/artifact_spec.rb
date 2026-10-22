require "rails_helper"

RSpec.describe Chorus::Artifact, type: :model do
  it "has a valid factory" do
    expect(build(:chorus_artifact)).to be_valid
  end

  describe "validations" do
    it "requires a name" do
      artifact = build(:chorus_artifact, name: nil)
      expect(artifact).not_to be_valid
      expect(artifact.errors[:name]).to be_present
    end

    it "is valid without a result (the producing run may be recorded later, §8)" do
      expect(build(:chorus_artifact, result: nil)).to be_valid
    end

    it "is valid with an open-vocabulary kind and a free-form locator" do
      expect(build(:chorus_artifact, kind: "okf_bundle", locator: "okf://bundle/42")).to be_valid
    end
  end

  describe "associations" do
    it "belongs to the result that produced it (optional, §8)" do
      reflection = described_class.reflect_on_association(:result)
      expect(reflection.macro).to eq(:belongs_to)
      expect(reflection.options[:optional]).to be(true)
    end

    it "no longer belongs to a workspace (the FK inverted onto Result)" do
      expect(described_class.reflect_on_association(:workspace)).to be_nil
    end
  end
end
