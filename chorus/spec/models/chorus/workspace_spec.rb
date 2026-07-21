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

  # Plan 011 §6: the workspace's markdown scope is a VIEWPORT into a host-seeded
  # bundle, not a bundle it creates for itself. The 010 has_one_okf :bundle /
  # materialize_bundle / doc_pathname machinery is gone.
  describe "the markdown viewport (§6)" do
    it "has_one_okf :view_port" do
      reflection = described_class.reflect_on_association(:view_port)
      expect(reflection.macro).to eq(:has_one)
      expect(reflection.options[:as]).to eq(:owner)
      expect(reflection.klass).to eq(CnfsOkf::ViewPort)
    end

    it "no longer creates its own bundle (machinery removed)" do
      expect(described_class.reflect_on_association(:bundle)).to be_nil
      expect(described_class.instance_methods).not_to include(:materialize_bundle, :doc_pathname)
    end
  end

  describe "validations" do
    it "requires a name" do
      workspace = build(:chorus_workspace, name: nil)
      expect(workspace).not_to be_valid
      expect(workspace.errors[:name]).to be_present
    end
  end

  describe "associations" do
    it "carries the role it was provisioned for (§6)" do
      expect(described_class.reflect_on_association(:role).macro).to eq(:belongs_to)
    end

    it "owns the sources checked out into it (§6)" do
      reflection = described_class.reflect_on_association(:sources)
      expect(reflection.macro).to eq(:has_many)
      expect(reflection.options[:as]).to eq(:owner)
    end

    it "no longer occupies a workable (the subject moved to WorkOrder, §4)" do
      expect(described_class.reflect_on_association(:workable)).to be_nil
      expect(described_class.column_names).not_to include("workable_id", "workable_type")
    end

    it "holds the work orders that landed against it, and its active claim (§6)" do
      expect(described_class.reflect_on_association(:work_orders).macro).to eq(:has_many)
      current = described_class.reflect_on_association(:current_work_order)
      expect(current.macro).to eq(:belongs_to)
      expect(current.options[:optional]).to be(true)
    end

    it "makes no structural claim on the Strategy → Project chain (org models left Chorus)" do
      expect(described_class.reflect_on_association(:active_project)).to be_nil
      expect(described_class.reflect_on_association(:projects)).to be_nil
    end
  end

  # Serial occupancy (§6): one work order active at a time, taken by an atomic
  # conditional update. The negative case is the point — a second claimant must be
  # refused, not silently overwrite the first.
  describe "#claim!" do
    let(:workspace) { create(:chorus_workspace) }
    let(:first)  { create(:chorus_work_order, workspace: workspace) }
    let(:second) { create(:chorus_work_order, workspace: workspace) }

    it "succeeds on an unclaimed workspace, stamping the claim" do
      expect(workspace.claim!(first)).to be(true)
      expect(workspace.reload.current_work_order_id).to eq(first.id)
      expect(workspace.claimed_at).to be_present
    end

    it "refuses a second claimant, leaving the first claim intact" do
      workspace.claim!(first)

      expect(workspace.claim!(second)).to be(false)
      expect(workspace.reload.current_work_order_id).to eq(first.id)
    end
  end

  describe "dependent destruction" do
    it "nullifies its work orders when destroyed (they outlive the place)" do
      workspace = create(:chorus_workspace)
      work_order = create(:chorus_work_order, workspace: workspace)

      workspace.destroy

      expect(Chorus::WorkOrder.exists?(work_order.id)).to be(true)
      expect(work_order.reload.workspace_id).to be_nil
    end
  end
end
