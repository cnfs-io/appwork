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

  # Plan 010 §4: the workspace gets a `doc/` bundle so authored documents (Plans)
  # have somewhere to live as Concepts. Rooted at `doc/`, not the workspace root.
  describe "#materialize_bundle (the doc/ OKF bundle)" do
    let(:root) { Dir.mktmpdir("chorus-ws-bundle") }
    before { allow(Chorus::Config).to receive(:workspace_root).and_return(root) }
    after  { FileUtils.remove_entry(root) if File.exist?(root) }

    let(:workspace) { create(:chorus_workspace) }

    it "creates the doc/ directory" do
      workspace.materialize_bundle
      expect(workspace.doc_pathname).to be_directory
    end

    it "creates an OKF Bundle rooted at doc/, not the workspace root" do
      bundle = workspace.materialize_bundle
      expect(bundle).to be_a(CnfsOkf::Bundle)
      expect(bundle).to be_persisted
      expect(bundle.path).to eq(workspace.doc_pathname.to_s)
      expect(bundle.owner).to eq(workspace)
    end

    it "is idempotent — a second call returns the same bundle, creating no new one" do
      first = workspace.materialize_bundle
      expect { workspace.materialize_bundle }.not_to change(CnfsOkf::Bundle, :count)
      expect(workspace.reload.bundle).to eq(first)
    end

    it "has_one_okf :bundle" do
      reflection = described_class.reflect_on_association(:bundle)
      expect(reflection.macro).to eq(:has_one)
      expect(reflection.options[:as]).to eq(:owner)
      expect(reflection.klass).to eq(CnfsOkf::Bundle)
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
