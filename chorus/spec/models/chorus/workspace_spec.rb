require "rails_helper"

RSpec.describe Chorus::Workspace, type: :model do
  it "has a valid factory" do
    expect(build(:chorus_workspace)).to be_valid
  end

  describe "validations" do
    it "requires a name" do
      workspace = build(:chorus_workspace, name: nil)
      expect(workspace).not_to be_valid
      expect(workspace.errors[:name]).to be_present
    end

    it "is valid without a workable (the slot is optional)" do
      expect(build(:chorus_workspace, workable: nil)).to be_valid
    end
  end

  describe "associations" do
    it { expect(described_class.reflect_on_association(:artifacts).macro).to eq(:has_many) }

    it "occupies a polymorphic workable" do
      reflection = described_class.reflect_on_association(:workable)
      expect(reflection.macro).to eq(:belongs_to)
      expect(reflection.options[:polymorphic]).to be(true)
    end

    it "marks workable as optional" do
      expect(described_class.reflect_on_association(:workable).options[:optional]).to be(true)
    end

    it "makes no structural claim on the Strategy → Project chain (org models left Chorus)" do
      expect(described_class.reflect_on_association(:active_project)).to be_nil
      expect(described_class.reflect_on_association(:projects)).to be_nil
    end
  end

  describe "dependent destruction" do
    it "destroys its artifacts when destroyed" do
      workspace = create(:chorus_workspace)
      artifact = create(:chorus_artifact, workspace: workspace)

      workspace.destroy

      expect(Chorus::Artifact.exists?(artifact.id)).to be(false)
    end
  end
end
