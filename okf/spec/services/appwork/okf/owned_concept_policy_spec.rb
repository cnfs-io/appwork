require "rails_helper"
require "tmpdir"
require "stringio"
require "logger"

# The owned-concept policy matrix and the DB->disk->DB round-trip, exercised
# through a REAL owner (Strategy) claiming a concept — the thing plan-1 left
# unwired. sync_spec proves the same branches with a bare Account owner; this
# suite proves they hold through Strategy's has_one_okf + frontmatter delegation,
# and adds the write-path-under-ownership cases that are the reason
# FsConcept#content= exists: a UI edit must NOT re-enter the sync loop as an
# update. See doc/plans/PLAN-cnfs-support-walker-and-cleanup.md Tier B4.
RSpec.describe "Appwork::Okf owned-concept policy" do
  def write_md(dir, rel, frontmatter: nil, body: "hello\n")
    path = File.join(dir, rel)
    FileUtils.mkdir_p(File.dirname(path))
    content = frontmatter ? "---\n#{frontmatter}---\n#{body}" : body
    File.write(path, content)
    path
  end

  # Flip owned_concept_policy for the block via ENV, resetting the memoized
  # singleton on both sides so policy never leaks across examples.
  def with_policy(policy)
    ENV["APPWORK_OKF_OWNED_CONCEPT_POLICY"] = policy.to_s
    Appwork::Okf::Config.reset_instance!
    yield
  ensure
    ENV.delete("APPWORK_OKF_OWNED_CONCEPT_POLICY")
    Appwork::Okf::Config.reset_instance!
  end

  # Capture log output for the duration of the block via a StringIO backend.
  def captured_logs
    io = StringIO.new
    Partitia::Support::Logging.backend = ::Logger.new(io)
    yield
    io.string
  ensure
    Partitia::Support::Logging.reset!
  end

  around do |example|
    Dir.mktmpdir("okf-policy") do |root|
      @root = root
      example.run
    end
  end

  # A bundle at @root/bundle with the given files already reconciled.
  def bundle_with(*files)
    dir = File.join(@root, "bundle")
    files.each { |rel, opts| write_md(dir, rel, **(opts || {})) }
    Appwork::Okf::Bundle.create!(path: dir)
  end

  # A Strategy that CLAIMS an existing concept (ownership points at a file; it
  # does not create one). This is what activates Sync's owned_concept_policy
  # branch — an owner_id present on the concept.
  def strategy_owning(concept)
    account  = Account.create!(title: "Acme")
    strategy = account.strategies.create!(title: "Q3 Expansion")
    strategy.update!(concept: concept)
    strategy
  end

  def concept_at(rel, **opts)
    bundle = bundle_with([ rel, opts ])
    [ bundle, bundle.concepts.find_by!(path: rel) ]
  end

  describe ":disk_wins" do
    it "follows a disk edit of an owned concept (updated == 1)" do
      bundle, concept = concept_at("s.md", frontmatter: "title: Original\n")
      strategy_owning(concept)
      write_md(bundle.path, "s.md", frontmatter: "title: Changed\n")

      result = with_policy(:disk_wins) { Appwork::Okf::Sync.call(bundle: bundle) }

      expect(result.updated).to eq(1)
      expect(concept.reload.title).to eq("Changed")
    end

    it "destroys an owned concept whose file was deleted, orphaning the owner" do
      bundle, concept = concept_at("s.md", frontmatter: "title: Original\n")
      strategy = strategy_owning(concept)
      File.delete(File.join(bundle.path, "s.md"))

      result = with_policy(:disk_wins) { Appwork::Okf::Sync.call(bundle: bundle) }

      expect(result.destroyed).to eq(1)
      expect(strategy.reload.concept).to be_nil
    end
  end

  describe ":protect" do
    it "keeps an owned concept whose file was deleted (skipped == 1, warning logged)" do
      bundle, concept = concept_at("s.md", frontmatter: "title: Original\n")
      strategy = strategy_owning(concept)
      File.delete(File.join(bundle.path, "s.md"))

      logs = captured_logs do
        result = with_policy(:protect) { Appwork::Okf::Sync.call(bundle: bundle) }
        expect(result.skipped).to eq(1)
        expect(result.destroyed).to eq(0)
      end

      expect(concept.reload).to be_persisted
      expect(strategy.reload.concept).to eq(concept)
      expect(logs).to match(/skipping stale owned concept/)
    end

    it "follows a disk edit — :protect guards deletion, not content (updated == 1)" do
      bundle, concept = concept_at("s.md", frontmatter: "title: Original\n")
      strategy_owning(concept)
      write_md(bundle.path, "s.md", frontmatter: "title: Changed\n")

      result = with_policy(:protect) { Appwork::Okf::Sync.call(bundle: bundle) }

      expect(result.updated).to eq(1)
      expect(concept.reload.title).to eq("Changed")
    end
  end

  describe ":quarantine" do
    it "declines a disk edit and leaves the owned concept detectably diverged" do
      bundle, concept = concept_at("s.md", frontmatter: "title: Original\n")
      strategy_owning(concept)
      write_md(bundle.path, "s.md", frontmatter: "title: CLOBBERED\n")

      result = with_policy(:quarantine) { Appwork::Okf::Sync.call(bundle: bundle) }

      expect(result.quarantined).to eq(1)
      expect(result.updated).to eq(0)
      expect(concept.reload.title).to eq("Original")
      expect(concept.diverged?).to be(true) # stale content_hash IS the signal
    end
  end

  describe "unowned concepts" do
    %i[protect quarantine disk_wins].each do |policy|
      it "are always reconciled disk-wins, regardless of the :#{policy} policy" do
        bundle, concept = concept_at("s.md", frontmatter: "title: Original\n")
        write_md(bundle.path, "s.md", frontmatter: "title: Changed\n")

        result = with_policy(policy) { Appwork::Okf::Sync.call(bundle: bundle) }

        expect(result.updated).to eq(1)
        expect(concept.reload.title).to eq("Changed")
      end
    end
  end

  # The write path is why FsConcept#content= exists: a UI edit routes DB->disk,
  # restamps content_hash, and MUST NOT re-enter Sync as an update. Exercised on
  # an OWNED concept, under the default :protect policy.
  describe "write-path under ownership (feedback-loop short-circuit)" do
    it "a UI body edit writes disk, restamps the hash, and Sync then reports unchanged" do
      bundle, concept = concept_at("s.md", frontmatter: "title: Original\n")
      strategy = strategy_owning(concept)

      strategy.concept.content = "edited in the UI"
      strategy.concept.save!

      # Disk holds the new body; hash matches the new bytes.
      expect(concept.pathname.read).to end_with("edited in the UI\n")
      expect(concept.content_hash).to eq(Digest::MD5.hexdigest(concept.pathname.read))

      result = Appwork::Okf::Sync.call(bundle: bundle)

      # THE key assertion: the hash short-circuit terminates the DB->disk->DB
      # loop. If this says updated=1 the listener would churn the filesystem.
      expect(result.unchanged).to eq(1)
      expect(result.updated).to eq(0)
    end

    it "a custom frontmatter edit (priority) round-trips to YAML, body untouched" do
      bundle, concept = concept_at(
        "s.md", frontmatter: "title: Q3\npriority: high\n", body: "the body\n"
      )
      strategy = strategy_owning(concept)

      strategy.priority = "low"
      strategy.concept.save!

      raw = concept.pathname.read
      expect(YAML.safe_load(raw[/\A---\n(.*?)\n---/m, 1])["priority"]).to eq("low")
      expect(raw).to end_with("the body\n")
      expect(strategy.reload.priority).to eq("low")
    end
  end
end
