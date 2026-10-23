# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

# Direct specs for Bundle + the FsBundle concern (#mv, the ino_match?
# short-circuit, and the read helpers) — paths that sync_spec/instrumentation_spec
# only exercise indirectly. Real files in a tmpdir, matching house style.
RSpec.describe CnfsOkf::Bundle do
  def write_md(dir, rel, frontmatter: nil, body: "hello\n")
    path = File.join(dir, rel)
    FileUtils.mkdir_p(File.dirname(path))
    content = frontmatter ? "---\n#{frontmatter}---\n#{body}" : body
    File.write(path, content)
    path
  end

  around do |example|
    Dir.mktmpdir("okf-bundle") do |root|
      @root = root
      example.run
    end
  end

  # A bundle rooted at @root/bundle with the given files already reconciled.
  def bundle_with(*files)
    dir = File.join(@root, "bundle")
    files.each { |rel| write_md(dir, rel) }
    CnfsOkf::Bundle.create!(path: dir)
  end

  describe "#mv" do
    it "renames the directory on disk and updates path" do
      bundle = bundle_with("alpha.md")
      dest   = File.join(@root, "moved")

      expect(bundle.mv(dest)).to be_truthy
      expect(File.exist?(File.join(dest, "alpha.md"))).to be(true)
      expect(File.exist?(File.join(@root, "bundle"))).to be(false)
      expect(bundle.reload.path).to eq(dest)
    end

    it "does not reconcile concepts when the root merely moved on the same fs" do
      bundle = bundle_with("alpha.md", "sub/beta.md")
      ids    = bundle.concepts.pluck(:id).sort

      # The in-place rename keeps every inode, so ino_match? should short-circuit
      # before Sync is ever called.
      expect(CnfsOkf::Sync).not_to receive(:call)
      bundle.mv(File.join(@root, "moved"))

      expect(bundle.reload.concepts.pluck(:id).sort).to eq(ids)
    end

    it "returns false and does not move when the destination exists" do
      bundle = bundle_with("alpha.md")
      dest   = File.join(@root, "taken")
      FileUtils.mkdir_p(dest)

      expect(bundle.mv(dest)).to be(false)
      expect(bundle.reload.path).to eq(File.join(@root, "bundle"))
    end

    it "returns false and does not move when the parent directory is missing" do
      bundle = bundle_with("alpha.md")
      dest   = File.join(@root, "no-such-parent", "moved")

      expect(bundle.mv(dest)).to be(false)
      expect(bundle.reload.path).to eq(File.join(@root, "bundle"))
    end
  end

  describe "read helpers" do
    it "#concept_paths lists every .md relative to the bundle root" do
      bundle = bundle_with("alpha.md", "sub/beta.md")

      expect(bundle.concept_paths.map(&:to_s)).to contain_exactly("alpha.md", "sub/beta.md")
    end

    it "#tree returns the unique set of concept directories" do
      bundle = bundle_with("alpha.md", "sub/beta.md", "sub/gamma.md")

      expect(bundle.tree.map(&:to_s)).to contain_exactly(".", "sub")
    end

    it "#ls scopes concepts to a viewport subdirectory" do
      bundle = bundle_with("alpha.md", "sub/beta.md")

      expect(bundle.ls("sub").pluck(:path)).to contain_exactly("sub/beta.md")
    end
  end
end
