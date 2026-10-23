require "rails_helper"

RSpec.describe Appwork::Chorus::Source, type: :model do
  describe "the STI base" do
    it "cannot be persisted without a concrete type" do
      base = Appwork::Chorus::Source.new(resource: "git@github.com:acme/repo.git")
      expect(base).not_to be_valid
      expect(base.errors[:type]).to be_present
    end

    it "requires a resource" do
      source = build(:appwork_chorus_source_git, resource: nil)
      expect(source).not_to be_valid
      expect(source.errors[:resource]).to be_present
    end

    it "leaves the transport interface unimplemented" do
      base = Appwork::Chorus::Source.new
      expect { base.fetch }.to raise_error(NotImplementedError)
      expect { base.refresh }.to raise_error(NotImplementedError)
      expect { base.current_ref }.to raise_error(NotImplementedError)
    end
  end

  describe "the settings bag" do
    it "defaults to an empty hash" do
      expect(Appwork::Chorus::Source::Git.new.settings).to eq({})
    end

    it "round-trips per-kind config through a declared accessor" do
      source = create(:appwork_chorus_source_git, :on_branch)
      expect(source.branch).to eq("main")
      expect(source.reload.settings).to eq("branch" => "main")
    end

    it "does not add per-kind columns to the table" do
      expect(Appwork::Chorus::Source.column_names).not_to include("branch")
    end
  end

  describe "ownership (§6)" do
    it "belongs to a polymorphic owner, optionally" do
      reflection = described_class.reflect_on_association(:owner)
      expect(reflection.macro).to eq(:belongs_to)
      expect(reflection.options[:polymorphic]).to be(true)
      expect(reflection.options[:optional]).to be(true)
    end

    it "a workspace owns the sources checked out into it" do
      workspace = create(:appwork_chorus_workspace)
      source = create(:appwork_chorus_source_git, owner: workspace)
      expect(source.reload.owner).to eq(workspace)
      expect(workspace.reload.sources).to contain_exactly(source)
    end
  end

  describe "STI" do
    it "resolves the concrete class from the type column" do
      git = create(:appwork_chorus_source_git)
      expect(Appwork::Chorus::Source.find(git.id)).to be_a(Appwork::Chorus::Source::Git)
    end

    it "has a valid git factory" do
      expect(build(:appwork_chorus_source_git)).to be_valid
    end
  end

  describe "staleness" do
    it "is stale when the upstream ref differs from the synced ref" do
      source = build(:appwork_chorus_source_git, :synced)
      allow(source).to receive(:current_ref).and_return("different-sha")
      expect(source).to be_stale
    end

    it "is not stale when the refs match" do
      source = build(:appwork_chorus_source_git, :synced)
      allow(source).to receive(:current_ref).and_return(source.ref)
      expect(source).not_to be_stale
    end
  end
end

RSpec.describe Appwork::Chorus::Source::Git, type: :model do
  # Coordination only: verify Git issues the right git operations and records
  # synced state. Efficacy (a real clone against a real remote) is a host-app
  # concern and is out of Chorus's testing scope.
  describe "#fetch" do
    it "clones the resource to the path and records the synced ref" do
      source = create(:appwork_chorus_source_git, :on_branch)
      allow(source).to receive(:run_git)
      allow(source).to receive(:capture_git).and_return("abc123\n")

      source.fetch

      expect(source).to have_received(:run_git)
        .with("clone", "--branch", "main", source.resource, source.path)
      expect(source.reload.ref).to eq("abc123")
      expect(source.synced_at).to be_present
    end

    it "omits the --branch flag when no branch is set" do
      source = create(:appwork_chorus_source_git)
      allow(source).to receive(:run_git)
      allow(source).to receive(:capture_git).and_return("abc123\n")

      source.fetch

      expect(source).to have_received(:run_git)
        .with("clone", source.resource, source.path)
    end
  end

  describe "#refresh" do
    it "fetches, hard-resets to the tracked ref, and records the new head" do
      source = create(:appwork_chorus_source_git, :on_branch, path: "/tmp/repo")
      allow(source).to receive(:run_git)
      allow(source).to receive(:capture_git).and_return("newsha\n")

      source.refresh

      expect(source).to have_received(:run_git).with("-C", "/tmp/repo", "fetch", "--all", "--prune")
      expect(source).to have_received(:run_git).with("-C", "/tmp/repo", "reset", "--hard", "main")
      expect(source.reload.ref).to eq("newsha")
    end
  end

  describe "#current_ref" do
    def stub_ls_remote(source, output)
      allow(source).to receive(:capture_git)
        .with("ls-remote", source.resource, source.branch.presence || "HEAD")
        .and_return(output)
    end

    it "parses the SHA from a single ls-remote line" do
      source = build(:appwork_chorus_source_git, :on_branch)
      stub_ls_remote(source, "deadbeef\trefs/heads/main\n")
      expect(source.current_ref).to eq("deadbeef")
    end

    it "returns nil when the ref does not exist upstream (empty output)" do
      source = build(:appwork_chorus_source_git, :on_branch)
      stub_ls_remote(source, "")
      expect(source.current_ref).to be_nil
    end

    it "prefers the peeled commit for an annotated tag" do
      # An annotated tag yields the tag object first, then the peeled commit.
      source = build(:appwork_chorus_source_git)
      source.branch = "v1.0"
      stub_ls_remote(source, "tagobjectsha\trefs/tags/v1.0\npeeledcommitsha\trefs/tags/v1.0^{}\n")
      expect(source.current_ref).to eq("peeledcommitsha")
    end

    it "skips malformed lines lacking a tab separator" do
      source = build(:appwork_chorus_source_git, :on_branch)
      stub_ls_remote(source, "garbage-without-tab\nrealsha\trefs/heads/main\n")
      expect(source.current_ref).to eq("realsha")
    end
  end

  describe "the shell boundary" do
    it "raises with context when a captured git command fails" do
      source = build(:appwork_chorus_source_git)
      # Drive the real #capture_git against a git subcommand that fails fast
      # without touching the network, to exercise the error path.
      expect { source.send(:capture_git, "rev-parse", "--verify", "definitely-not-a-ref") }
        .to raise_error(/failed/)
    end
  end

  # Verify the CNFS instrumentation contract at the notification layer (no OTel
  # SDK). Every Source kind emits under the `partitia_appwork.source.*` prefix — pinned in
  # the STI base so a three-level subclass name does not leak "chorus/source"
  # into the component tag. We assert event names and payloads directly.
  describe "instrumentation" do
    # Collect every notification matching `pattern` fired during the block as
    # [name, payload] pairs.
    def capture_events(pattern)
      events = []
      callback = ->(name, _start, _finish, _id, payload) { events << [ name, payload ] }
      ActiveSupport::Notifications.subscribed(callback, pattern) { yield }
      events
    end

    it "emits partitia_appwork.source.fetch with a useful payload" do
      source = create(:appwork_chorus_source_git, :on_branch)
      allow(source).to receive(:run_git)
      allow(source).to receive(:capture_git).and_return("abc123\n")

      events = capture_events("partitia_appwork.source.fetch") { source.fetch }

      expect(events.size).to eq(1)
      name, payload = events.first
      expect(name).to eq("partitia_appwork.source.fetch")
      expect(payload).to include(source_id: source.id, resource: source.resource, path: source.path)
    end

    it "emits partitia_appwork.source.refresh with a useful payload" do
      source = create(:appwork_chorus_source_git, :on_branch, path: "/tmp/repo")
      allow(source).to receive(:run_git)
      allow(source).to receive(:capture_git).and_return("newsha\n")

      events = capture_events("partitia_appwork.source.refresh") { source.refresh }

      expect(events.size).to eq(1)
      _name, payload = events.first
      expect(payload).to include(source_id: source.id, path: "/tmp/repo", tracking_ref: "main")
    end

    it "emits partitia_appwork.source.current_ref with a useful payload" do
      source = build(:appwork_chorus_source_git, :on_branch)
      allow(source).to receive(:capture_git).and_return("deadbeef\trefs/heads/main\n")

      events = capture_events("partitia_appwork.source.current_ref") { source.current_ref }

      expect(events.size).to eq(1)
      _name, payload = events.first
      expect(payload).to include(source_id: source.id, resource: source.resource, tracking_ref: "main")
    end

    it "emits a partitia_appwork.source.git_exec span at the shell boundary, carrying the command" do
      source = build(:appwork_chorus_source_git)

      events = capture_events("partitia_appwork.source.git_exec") do
        # Harmless, offline git subcommand — no network, always succeeds.
        source.send(:capture_git, "--version")
      end

      expect(events.size).to eq(1)
      name, payload = events.first
      expect(name).to eq("partitia_appwork.source.git_exec")
      expect(payload[:cmd]).to eq("git --version")
    end

    it "marks the git_exec event with the exception when the command fails" do
      source = build(:appwork_chorus_source_git)

      events = capture_events("partitia_appwork.source.git_exec") do
        expect { source.send(:capture_git, "rev-parse", "--verify", "definitely-not-a-ref") }
          .to raise_error(/failed/)
      end

      expect(events.size).to eq(1)
      _name, payload = events.first
      # ActiveSupport::Notifications stamps :exception on the payload when the
      # instrumented block raises — this is what turns it into an error span.
      expect(payload[:exception]).to be_present
    end
  end
end
