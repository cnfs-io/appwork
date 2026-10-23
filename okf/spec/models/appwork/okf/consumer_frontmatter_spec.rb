# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

# The okf_frontmatter accessor macro (Appwork::Okf::Consumer). Generates a
# read/write accessor pair over the owned concept's serialized
# custom_frontmatter Hash, replacing the hand-written priority/priority= that
# Strategy used to carry. Accessor-only: no column, no projection, nothing
# subscribes. See doc/plans/006-frontmatter-macro.md.
#
# The load-bearing contract is the read/write nil-safety ASYMMETRY: read is
# `&.`-guarded (concept-less -> nil), write is NOT (concept-less -> raises).
# Both halves are pinned below — the write case especially, because it is the
# one someone will later "fix" into silent nil-handling and break the contract.
RSpec.describe "Appwork::Okf::Consumer#okf_frontmatter" do
  def write_md(dir, rel, frontmatter: nil, body: "hello\n")
    path = File.join(dir, rel)
    FileUtils.mkdir_p(File.dirname(path))
    content = frontmatter ? "---\n#{frontmatter}---\n#{body}" : body
    File.write(path, content)
    path
  end

  around do |example|
    Dir.mktmpdir("okf-frontmatter") do |root|
      @root = root
      example.run
    end
  end

  # A Strategy that CLAIMS an existing on-disk concept (ownership points at a
  # file). Mirrors owned_concept_policy_spec's setup.
  def strategy_owning_concept(rel, **opts)
    dir = File.join(@root, "bundle")
    write_md(dir, rel, **opts)
    bundle   = Appwork::Okf::Bundle.create!(path: dir)
    concept  = bundle.concepts.find_by!(path: rel)
    account  = Account.create!(title: "Acme")
    strategy = account.strategies.create!(title: "Q3 Expansion")
    strategy.update!(concept: concept)
    strategy
  end

  # A Strategy that genuinely owns NO concept — no bundle, no claim, nothing
  # auto-builds one. This is the fixture that makes the nil/raise branches
  # testable; a seed/factory path that auto-claims a concept would hide them.
  def concept_less_strategy
    Account.create!(title: "Acme").strategies.create!(title: "Orphan")
  end

  describe "read accessor (nil-safe)" do
    it "returns the custom_frontmatter value for the declared key" do
      strategy = strategy_owning_concept("s.md", frontmatter: "title: Q3\npriority: high\n")

      expect(strategy.priority).to eq("high")
    end

    it "returns nil when the owned concept has no such custom key" do
      strategy = strategy_owning_concept("s.md", frontmatter: "title: Q3\n")

      expect(strategy.priority).to be_nil
    end

    it "returns nil (no raise) when the consumer owns no concept yet" do
      expect(concept_less_strategy.priority).to be_nil
    end
  end

  describe "write accessor (concept-first, NOT nil-guarded)" do
    it "stores the value in the concept's custom_frontmatter" do
      strategy = strategy_owning_concept("s.md", frontmatter: "title: Q3\n")

      strategy.priority = "high"

      expect(strategy.concept.custom_frontmatter).to eq("priority" => "high")
    end

    it "merges into existing custom_frontmatter without clobbering other keys" do
      strategy = strategy_owning_concept("s.md", frontmatter: "title: Q3\nowner: rob\n")

      strategy.priority = "low"

      expect(strategy.concept.custom_frontmatter).to eq("owner" => "rob", "priority" => "low")
    end

    it "persists the value to disk via the existing persist_to_disk path" do
      strategy = strategy_owning_concept("s.md", frontmatter: "title: Q3\n", body: "the body\n")

      strategy.priority = "high"
      strategy.concept.save!

      raw = strategy.concept.pathname.read
      expect(YAML.safe_load(raw[/\A---\n(.*?)\n---/m, 1])["priority"]).to eq("high")
      expect(raw).to end_with("the body\n")
      expect(strategy.reload.priority).to eq("high")
    end

    # THE contract that must not be "fixed" into silent nil-handling: the write
    # accessor has no nil-guard on `concept`, so a concept-less consumer raises.
    it "raises NoMethodError when the consumer owns no concept" do
      strategy = concept_less_strategy

      expect { strategy.priority = "high" }.to raise_error(NoMethodError)
    end
  end
end
