require "rails_helper"
require "tmpdir"

RSpec.describe Chorus::Workspace, type: :model do
  it "has a valid factory" do
    expect(build(:chorus_workspace)).to be_valid
  end

  # # 009 the Workspace IS a directory on disk — the run's cwd, the skills home, and
  # where output lands. Materialized on demand under a host-configured root, keyed
  # by id (deterministic), and never deleted.
  describe "#pathname / #materialize (the execution directory)" do
    let(:root) { Dir.mktmpdir("chorus-ws-spec") }
    before { allow(Chorus::Config).to receive(:workspace_root).and_return(root) }
    after  { FileUtils.remove_entry(root) if File.exist?(root) }

    let(:workspace) { create(:chorus_workspace) }

    it "derives a deterministic path under the configured root, keyed by id" do
      expect(workspace.directory).to eq(Pathname.new(root).join(workspace.id.to_s))
    end

    it "is stable across calls (same path every time)" do
      expect(workspace.pathname).to eq(workspace.pathname)
    end

    it "materializes the directory on demand" do
      expect(workspace.pathname).to be_directory
    end

    it "is idempotent and never deletes existing contents" do
      marker = workspace.pathname.join("keep.txt")
      marker.write("hello")

      workspace.materialize   # second call must not clobber

      expect(marker).to exist
      expect(marker.read).to eq("hello")
    end

    it "expands ~ in the configured root" do
      allow(Chorus::Config).to receive(:workspace_root).and_return("~/.chorus/ws-spec")
      expect(workspace.directory.to_s).to start_with(File.expand_path("~/.chorus/ws-spec"))
    end

    it "raises for an unpersisted workspace (a programmer error, not operational)" do
      expect { build(:chorus_workspace).directory }.to raise_error(/must be persisted/)
    end
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
