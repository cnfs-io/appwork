# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

# Direct specs for the derived Concept logic (#diverged?, frontmatter mapping)
# that sync_spec leans on but never asserts in isolation.
RSpec.describe CnfsOkf::Concept do
  def write_md(dir, rel, frontmatter: nil, body: "hello\n")
    path = File.join(dir, rel)
    FileUtils.mkdir_p(File.dirname(path))
    content = frontmatter ? "---\n#{frontmatter}---\n#{body}" : body
    File.write(path, content)
    path
  end

  around do |example|
    Dir.mktmpdir("okf-concept") do |root|
      @root = root
      example.run
    end
  end

  # A bundle at @root/bundle holding one reconciled concept file.
  def concept_for(rel, **opts)
    dir = File.join(@root, "bundle")
    write_md(dir, rel, **opts)
    CnfsOkf::Bundle.create!(path: dir).concepts.find_by!(path: rel)
  end

  describe "#diverged?" do
    it "is false when the file on disk matches the recorded hash" do
      expect(concept_for("alpha.md", frontmatter: "title: A\n").diverged?).to be(false)
    end

    it "is true once the file changes on disk behind the DB" do
      concept = concept_for("alpha.md", frontmatter: "title: A\n")
      File.write(concept.pathname, "---\ntitle: Changed\n---\nhello\n")

      expect(concept.diverged?).to be(true)
    end

    it "is false when the file no longer exists" do
      concept = concept_for("alpha.md")
      File.delete(concept.pathname)

      expect(concept.diverged?).to be(false)
    end
  end

  describe "frontmatter mapping" do
    it "populates known columns and files unknown keys under custom_frontmatter" do
      concept = concept_for("alpha.md", frontmatter: "title: Foo\ntags:\n  - a\npriority: high\n")

      expect(concept.title).to eq("Foo")
      expect(concept.tags).to eq([ "a" ])
      expect(concept.custom_frontmatter).to eq({ "priority" => "high" })
    end

    it "does not clobber a locally-changed column with the disk value" do
      concept = concept_for("alpha.md", frontmatter: "title: Disk\n")
      concept.title = "Local"

      concept.send(:ident) # re-reads disk; must respect the pending local change

      expect(concept.title).to eq("Local")
    end
  end
end
