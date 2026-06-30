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

    it "requires an organization" do
      expect(build(:chorus_workspace, organization: nil)).not_to be_valid
    end

    it "is valid without an active project (the slot is optional)" do
      expect(build(:chorus_workspace, active_project: nil)).to be_valid
    end
  end

  describe "associations" do
    it { expect(described_class.reflect_on_association(:organization).macro).to eq(:belongs_to) }
    it { expect(described_class.reflect_on_association(:artifacts).macro).to eq(:has_many) }

    it "marks active_project as optional" do
      expect(described_class.reflect_on_association(:active_project).options[:optional]).to be(true)
    end

    it "does not couple to projects except through the active slot" do
      expect(described_class.reflect_on_association(:projects)).to be_nil
    end
  end

  describe "the active project slot" do
    it "hosts at most one active project at a time" do
      workspace = create(:chorus_workspace)
      project = create(:chorus_project)
      workspace.update!(active_project: project)
      expect(workspace.reload.active_project).to eq(project)
    end
  end

  describe "dependent destruction" do
    it "destroys its artifacts when destroyed" do
      workspace = create(:chorus_workspace)
      artifact = create(:chorus_artifact, workspace: workspace)

      workspace.destroy

      expect(Chorus::Artifact.exists?(artifact.id)).to be(false)
    end

    it "does not destroy its active project when destroyed" do
      project = create(:chorus_project)
      workspace = create(:chorus_workspace, active_project: project)

      workspace.destroy

      expect(Chorus::Project.exists?(project.id)).to be(true)
    end
  end
end
