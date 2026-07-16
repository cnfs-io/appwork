require "rails_helper"

RSpec.describe Chorus::SkillCatalog, type: :model do
  subject(:catalog) { described_class.new }

  def fixture(name)
    File.read(File.expand_path("../../fixtures/skills/#{name}", __dir__))
  end

  # The two shell seams are the mock points — exactly as Source::Git's git seams
  # are stubbed. No spec here invokes a real npx or touches the network.
  describe "argv construction (never invokes real npx)" do
    describe "#add" do
      it "installs project-scoped by default — no -g" do
        allow(catalog).to receive(:run_npx)
        catalog.add("acme/repo")
        expect(catalog).to have_received(:run_npx).with("add", "acme/repo", chdir: nil)
      end

      it "passes -g ONLY when global: true is asked for explicitly" do
        allow(catalog).to receive(:run_npx)
        catalog.add("acme/repo", global: true)
        expect(catalog).to have_received(:run_npx).with("add", "acme/repo", "-g", chdir: nil)
      end

      it "appends --skill for a single skill" do
        allow(catalog).to receive(:run_npx)
        catalog.add("acme/repo", skill: "react-best-practices")
        expect(catalog).to have_received(:run_npx)
          .with("add", "acme/repo", "--skill", "react-best-practices", chdir: nil)
      end

      it "repeats -a per agent" do
        allow(catalog).to receive(:run_npx)
        catalog.add("acme/repo", agents: %w[claude cursor])
        expect(catalog).to have_received(:run_npx)
          .with("add", "acme/repo", "-a", "claude", "-a", "cursor", chdir: nil)
      end

      it "scopes the install to the given path (chdir)" do
        allow(catalog).to receive(:run_npx)
        catalog.add("acme/repo", path: "/tmp/ws")
        expect(catalog).to have_received(:run_npx).with("add", "acme/repo", chdir: "/tmp/ws")
      end
    end

    describe "#search" do
      it "builds a plain find" do
        allow(catalog).to receive(:capture_npx).and_return("")
        catalog.search("react")
        expect(catalog).to have_received(:capture_npx).with("find", "react")
      end

      it "adds --owner when scoped" do
        allow(catalog).to receive(:capture_npx).and_return("")
        catalog.search("react", owner: "vercel-labs")
        expect(catalog).to have_received(:capture_npx).with("find", "react", "--owner", "vercel-labs")
      end
    end

    describe "#list_repo_skills" do
      it "builds add <resource> --list" do
        allow(catalog).to receive(:capture_npx).and_return("")
        catalog.list_repo_skills("vercel-labs/agent-skills")
        expect(catalog).to have_received(:capture_npx).with("add", "vercel-labs/agent-skills", "--list")
      end
    end

    describe "#update" do
      it "passes -g for a global scope" do
        allow(catalog).to receive(:run_npx)
        catalog.update("foo", scope: :global)
        expect(catalog).to have_received(:run_npx).with("update", "foo", "-g")
      end

      it "passes -p for a project scope" do
        allow(catalog).to receive(:run_npx)
        catalog.update(scope: :project)
        expect(catalog).to have_received(:run_npx).with("update", "-p")
      end
    end

    describe "#remove" do
      it "repeats -a per agent" do
        allow(catalog).to receive(:run_npx)
        catalog.remove("foo", agents: %w[claude])
        expect(catalog).to have_received(:run_npx).with("remove", "foo", "-a", "claude")
      end
    end

    describe "#init" do
      it "runs a bare init" do
        allow(catalog).to receive(:run_npx)
        catalog.init
        expect(catalog).to have_received(:run_npx).with("init", chdir: nil)
      end

      it "names the skill and scopes the directory when given" do
        allow(catalog).to receive(:run_npx)
        catalog.init("my-skill", chdir: "/tmp/x")
        expect(catalog).to have_received(:run_npx).with("init", "my-skill", chdir: "/tmp/x")
      end
    end
  end

  describe "parsing (fed committed fixture strings)" do
    describe "#search parses `find` output" do
      before { allow(catalog).to receive(:capture_npx).and_return(fixture("find_react.txt")) }

      let(:results) { catalog.search("react") }

      it "extracts owner/repo, skill_name, and install_count for each hit" do
        top = results.first
        expect(top[:resource]).to eq("vercel-labs/agent-skills")
        expect(top[:skill_name]).to eq("vercel-react-best-practices")
        expect(top[:install_count]).to eq(541_800)
      end

      it "parses a bare-thousands count (e.g. \"4K installs\")" do
        json = results.find { |r| r[:resource] == "vercel-labs/json-render" }
        expect(json[:skill_name]).to eq("react")
        expect(json[:install_count]).to eq(4_000)
      end

      it "leaves description nil (find does not carry it)" do
        expect(results).to all(include(description: nil))
      end

      it "finds every hit in the fixture" do
        expect(results.size).to eq(6)
      end
    end

    describe "#list_repo_skills parses `add --list` output" do
      before do
        allow(catalog).to receive(:capture_npx).and_return(fixture("add_list_vercel.txt"))
      end

      let(:skills) { catalog.list_repo_skills("vercel-labs/agent-skills") }

      it "stamps the resource in from the argument" do
        expect(skills).to all(include(resource: "vercel-labs/agent-skills"))
      end

      it "pairs each skill name with its description" do
        entry = skills.find { |s| s[:skill_name] == "vercel-composition-patterns" }
        expect(entry[:description]).to start_with("React composition patterns that scale.")
      end

      it "enumerates all skills the repo exposes" do
        names = skills.map { |s| s[:skill_name] }
        expect(names).to include(
          "vercel-composition-patterns", "deploy-to-vercel",
          "vercel-react-best-practices", "web-design-guidelines", "writing-guidelines"
        )
      end

      it "ignores the spinner/status noise before the skills header" do
        expect(skills.map { |s| s[:skill_name] }).to all(match(/\A[\w][\w.:-]*\z/))
      end
    end
  end

  describe "#ingest — the mirror-refresh entry point" do
    let(:entries) do
      [ { resource: "acme/repo", skill_name: "a", description: "first", install_count: 10 },
        { resource: "acme/repo", skill_name: "b", description: "second", install_count: 20 } ]
    end

    it "upserts CatalogSkill rows on the natural key and stamps synced_at" do
      records = catalog.ingest(entries)
      expect(Chorus::CatalogSkill.count).to eq(2)
      expect(records.map(&:synced_at)).to all(be_present)
      expect(Chorus::CatalogSkill.find_by(resource: "acme/repo", skill_name: "a").description).to eq("first")
    end

    it "updates rather than duplicates on a second ingest of the same skill" do
      catalog.ingest(entries)
      catalog.ingest([ { resource: "acme/repo", skill_name: "a", description: "updated", install_count: 99 } ])

      expect(Chorus::CatalogSkill.count).to eq(2)
      row = Chorus::CatalogSkill.find_by(resource: "acme/repo", skill_name: "a")
      expect(row.description).to eq("updated")
      expect(row.install_count).to eq(99)
    end

    it "does not clobber existing values with nils from a sparser refresh" do
      catalog.ingest([ { resource: "acme/repo", skill_name: "a", description: "keep me", install_count: 10 } ])
      # A `find`-sourced entry carries no description.
      catalog.ingest([ { resource: "acme/repo", skill_name: "a", description: nil, install_count: 12 } ])

      row = Chorus::CatalogSkill.find_by(resource: "acme/repo", skill_name: "a")
      expect(row.description).to eq("keep me")
      expect(row.install_count).to eq(12)
    end

    it "ingests a whole-repo entry (nil skill_name)" do
      catalog.ingest([ { resource: "acme/repo", skill_name: nil, description: "repo", install_count: 5 } ])
      expect(Chorus::CatalogSkill.find_by(resource: "acme/repo", skill_name: nil)).to be_present
    end
  end

  describe "search -> ingest composes end to end (still no real npx)" do
    it "mirrors what a `find` returned into CatalogSkill rows" do
      allow(catalog).to receive(:capture_npx).and_return(fixture("find_react.txt"))
      catalog.ingest(catalog.search("react"))

      row = Chorus::CatalogSkill.find_by(resource: "vercel-labs/agent-skills",
                                         skill_name: "vercel-react-best-practices")
      expect(row.install_count).to eq(541_800)
      expect(row.synced_at).to be_present
    end
  end

  describe "the shell boundary raises on non-zero (no real npx, no network)" do
    # We cannot drive a real npx offline (it always fetches the package), which
    # would violate the no-network rule. Instead exercise the raise path by
    # stubbing IO.popen and forcing a failed exit status via a subshell that
    # exits non-zero — $? is set by the stubbed read's backing process.
    it "raises with the captured output when the exit status is non-zero" do
      allow(IO).to receive(:popen) do |_argv, **_opts, &blk|
        # Run a trivial failing command so $? reflects a non-zero status, and
        # feed the block the "captured" text npx would have written to stdout.
        blk.call(StringIO.new("boom: something went wrong"))
        system("exit 3")   # sets $? to a non-zero Process::Status
        "boom: something went wrong"
      end

      expect { catalog.send(:capture_npx, "find", "x") }
        .to raise_error(/npx skills find x failed \(3\): boom: something went wrong/)
    end
  end

  # Verify the CNFS instrumentation contract at the notification layer — every
  # shell exec emits under the stable `cnfs_chorus.skill_catalog.*` prefix, and
  # never leaks a token/blob into the payload.
  describe "instrumentation" do
    def capture_events(pattern)
      events = []
      callback = ->(name, _s, _f, _id, payload) { events << [ name, payload ] }
      ActiveSupport::Notifications.subscribed(callback, pattern) { yield }
      events
    end

    it "emits cnfs_chorus.skill_catalog.npx_exec carrying the command" do
      allow(catalog).to receive(:system).and_return(true)
      events = capture_events("cnfs_chorus.skill_catalog.npx_exec") do
        catalog.add("acme/repo")
      end
      expect(events.size).to eq(1)
      name, payload = events.first
      expect(name).to eq("cnfs_chorus.skill_catalog.npx_exec")
      expect(payload[:cmd]).to eq("npx skills add acme/repo")
    end
  end
end
