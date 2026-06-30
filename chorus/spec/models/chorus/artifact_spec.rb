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

    it "requires a workspace" do
      expect(build(:chorus_artifact, workspace: nil)).not_to be_valid
    end

    it "is valid with an open-vocabulary kind and a free-form locator" do
      expect(build(:chorus_artifact, kind: "okf_bundle", locator: "okf://bundle/42")).to be_valid
    end
  end

  describe "associations" do
    it { expect(described_class.reflect_on_association(:workspace).macro).to eq(:belongs_to) }
  end
end
