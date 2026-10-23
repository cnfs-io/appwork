require "rails_helper"
require "tmpdir"

# Integration specs for Appwork::Okf::Sync against real files in a tmpdir — no
# filesystem mocking, matching the instrumentation_spec convention.
RSpec.describe Appwork::Okf::Sync do
  def write_md(dir, rel, frontmatter: nil, body: "hello\n")
    path = File.join(dir, rel)
    FileUtils.mkdir_p(File.dirname(path))
    content = frontmatter ? "---\n#{frontmatter}---\n#{body}" : body
    File.write(path, content)
    path
  end

  # Flip owned_concept_policy for the duration of the block via ENV, resetting the
  # memoized singleton on both sides so policy never leaks across examples.
  def with_policy(policy)
    ENV["APPWORK_OKF_OWNED_CONCEPT_POLICY"] = policy.to_s
    Appwork::Okf::Config.reset_instance!
    yield
  ensure
    ENV.delete("APPWORK_OKF_OWNED_CONCEPT_POLICY")
    Appwork::Okf::Config.reset_instance!
  end

  around do |example|
    Dir.mktmpdir("okf-sync") do |root|
      @root = root
      example.run
    end
  end

  # A bundle rooted at @root/bundle with the given files already reconciled.
  def bundle_with(*files)
    dir = File.join(@root, "bundle")
    files.each { |rel, opts| write_md(dir, rel, **(opts || {})) }
    Appwork::Okf::Bundle.create!(path: dir)
  end

  describe "create" do
    it "creates a concept for a new .md and applies its frontmatter" do
      bundle = bundle_with([ "alpha.md", { frontmatter: "title: Alpha\n" } ])
      write_md(bundle.path, "beta.md", frontmatter: "title: Beta\n")

      result = described_class.call(bundle: bundle)

      expect(result.created).to eq(1)
      beta = bundle.concepts.find_by!(path: "beta.md")
      expect(beta.title).to eq("Beta")
    end
  end

  describe "destroy" do
    it "destroys an unowned concept whose file was deleted" do
      bundle = bundle_with([ "alpha.md" ])
      File.delete(File.join(bundle.path, "alpha.md"))

      result = described_class.call(bundle: bundle)

      expect(result.destroyed).to eq(1)
      expect(bundle.concepts.reload).to be_empty
    end

    %i[protect quarantine].each do |policy|
      it "skips (does not destroy) an owned concept under :#{policy}" do
        bundle  = bundle_with([ "alpha.md" ])
        concept = bundle.concepts.find_by!(path: "alpha.md")
        concept.update!(owner: Account.create!(title: "Acme"))
        File.delete(File.join(bundle.path, "alpha.md"))

        result = with_policy(policy) { described_class.call(bundle: bundle) }

        expect(result.skipped).to eq(1)
        expect(result.destroyed).to eq(0)
        expect(concept.reload).to be_persisted
      end
    end

    it "destroys an owned concept under :disk_wins" do
      bundle  = bundle_with([ "alpha.md" ])
      concept = bundle.concepts.find_by!(path: "alpha.md")
      concept.update!(owner: Account.create!(title: "Acme"))
      File.delete(File.join(bundle.path, "alpha.md"))

      result = with_policy(:disk_wins) { described_class.call(bundle: bundle) }

      expect(result.destroyed).to eq(1)
      expect(bundle.concepts.reload).to be_empty
    end
  end

  describe "update" do
    it "follows the file for an unowned concept" do
      bundle = bundle_with([ "alpha.md", { frontmatter: "title: Original\n" } ])
      write_md(bundle.path, "alpha.md", frontmatter: "title: Changed\n")

      result = described_class.call(bundle: bundle)

      expect(result.updated).to eq(1)
      expect(bundle.concepts.find_by!(path: "alpha.md").title).to eq("Changed")
    end

    it "follows the file for an owned concept under :protect (protect guards deletion, not content)" do
      bundle  = bundle_with([ "alpha.md", { frontmatter: "title: Original\n" } ])
      concept = bundle.concepts.find_by!(path: "alpha.md")
      concept.update!(owner: Account.create!(title: "Acme"))
      write_md(bundle.path, "alpha.md", frontmatter: "title: Changed\n")

      result = with_policy(:protect) { described_class.call(bundle: bundle) }

      expect(result.updated).to eq(1)
      expect(concept.reload.title).to eq("Changed")
    end
  end

  describe "quarantine" do
    it "leaves an owned concept's DB attributes untouched and detectably diverged" do
      bundle  = bundle_with([ "alpha.md", { frontmatter: "title: Original\n" } ])
      concept = bundle.concepts.find_by!(path: "alpha.md")
      concept.update!(owner: Account.create!(title: "Acme"))
      write_md(bundle.path, "alpha.md", frontmatter: "title: AGENT CLOBBERED THIS\n")

      result = with_policy(:quarantine) { described_class.call(bundle: bundle) }

      expect(result.quarantined).to eq(1)
      expect(result.updated).to eq(0)
      expect(concept.reload.title).to eq("Original")
      expect(concept.diverged?).to be(true)
    end
  end

  describe "idempotence" do
    it "the second call reports all-unchanged and performs zero writes" do
      bundle = bundle_with([ "alpha.md", { frontmatter: "title: Original\n" } ])
      write_md(bundle.path, "alpha.md", frontmatter: "title: Changed\n")

      described_class.call(bundle: bundle) # first: updates
      result = described_class.call(bundle: bundle) # second: no-op

      expect(result.created).to eq(0)
      expect(result.updated).to eq(0)
      expect(result.destroyed).to eq(0)
      expect(result.unchanged).to eq(1)
    end
  end

  describe "no write-back" do
    it "does not rewrite the file when updating a concept from disk (asserts on bytes)" do
      bundle = bundle_with([ "alpha.md", { frontmatter: "title: Original\n" } ])
      path   = File.join(bundle.path, "alpha.md")
      edited = "---\ntitle: Changed\n---\nhello\n"
      File.write(path, edited)

      result = described_class.call(bundle: bundle)

      expect(result.updated).to eq(1)
      expect(File.binread(path)).to eq(edited)
    end
  end

  describe "paths: scoping" do
    it "does not destroy a concept outside the scoped paths" do
      bundle = bundle_with([ "a.md" ], [ "b.md" ])
      File.delete(File.join(bundle.path, "b.md"))

      result = described_class.call(bundle: bundle, paths: [ "a.md" ])

      expect(result.destroyed).to eq(0)
      expect(bundle.concepts.reload.pluck(:path)).to contain_exactly("a.md", "b.md")
    end
  end

  describe "policy validation" do
    it "raises when owned_concept_policy is invalid" do
      with_policy(:bogus) do
        expect { Appwork::Okf::Config.owned_concept_policy }
          .to raise_error(Anyway::Config::ValidationError, /owned_concept_policy must be one of/)
      end
    end
  end
end
