# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

# ViewPort had zero direct coverage. Exercises the LIKE-based concept scoping,
# the directory validation, and #tree against real files in a tmpdir.
RSpec.describe Appwork::Okf::ViewPort do
  def write_md(dir, rel, body: "hello\n")
    path = File.join(dir, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, body)
    path
  end

  around do |example|
    Dir.mktmpdir("okf-viewport") do |root|
      @root = root
      example.run
    end
  end

  def bundle_with(*files)
    dir = File.join(@root, "bundle")
    files.each { |rel| write_md(dir, rel) }
    Appwork::Okf::Bundle.create!(path: dir)
  end

  describe "#concepts" do
    it "returns every bundle concept for the root viewport (empty path)" do
      bundle = bundle_with("a/x.md", "b/y.md")

      expect(bundle.view_ports.build(path: "").concepts.pluck(:path))
        .to contain_exactly("a/x.md", "b/y.md")
    end

    it "scopes to a subdirectory via the LIKE prefix" do
      bundle = bundle_with("a/x.md", "b/y.md")

      expect(bundle.view_ports.build(path: "a").concepts.pluck(:path))
        .to contain_exactly("a/x.md")
    end
  end

  describe "path_must_be_directory" do
    it "is valid on a directory path" do
      bundle = bundle_with("a/x.md")

      expect(bundle.view_ports.build(path: "a")).to be_valid
    end

    it "is invalid on a file path" do
      bundle = bundle_with("a/x.md")
      vp     = bundle.view_ports.build(path: "a/x.md")

      expect(vp).not_to be_valid
      expect(vp.errors[:path].join).to match(/is not a directory/)
    end
  end

  describe "#tree" do
    it "returns the unique relative subdirectories under the viewport root" do
      bundle = bundle_with("a/x.md", "b/y.md")

      expect(bundle.view_ports.build(path: "").tree.map(&:to_s))
        .to contain_exactly("a", "b")
    end
  end

  describe "materialize: true" do
    it "creates the directory and persists a valid record with ino set" do
      bundle = bundle_with("a/x.md")

      vp = bundle.view_ports.create!(path: "plans", materialize: true)

      expect(vp).to be_persisted
      expect(vp.ino).to be_present
      expect(File.directory?(File.join(bundle.path, "plans"))).to be(true)
    end

    it "creates all intermediate directories (mkpath)" do
      bundle = bundle_with("a/x.md")

      vp = bundle.view_ports.create!(path: "a/b/c", materialize: true)

      expect(vp).to be_valid
      expect(File.directory?(File.join(bundle.path, "a/b/c"))).to be(true)
    end

    it "is a no-op on an already-existing directory" do
      bundle = bundle_with("a/x.md")

      expect { bundle.view_ports.create!(path: "a", materialize: true) }.not_to raise_error
    end

    it "does not clobber an existing file at the path" do
      bundle = bundle_with("a/x.md")

      # materialize_path guards on `unless pathname.exist?` (plan §1), so a path
      # that already exists as a file is never mkpath'd — it's rejected by the
      # existing directory validation instead, and the file is left untouched.
      expect { bundle.view_ports.create!(path: "a/x.md", materialize: true) }
        .to raise_error(ActiveRecord::RecordInvalid, /is not a directory/)
      expect(File.read(File.join(bundle.path, "a/x.md"))).to eq("hello\n")
    end
  end

  describe "a missing directory without materialize" do
    it "is invalid and the error names `materialize: true` (not `ino can't be blank`)" do
      bundle = bundle_with("a/x.md")
      vp     = bundle.view_ports.build(path: "plans")

      expect(vp).not_to be_valid
      expect(vp.errors[:path].join).to match(/pass `materialize: true` to create it/)
      expect(File.exist?(File.join(bundle.path, "plans"))).to be(false)
    end
  end

  describe "containment within the bundle" do
    it "rejects a path escaping the bundle root and creates nothing, without materialize" do
      bundle = bundle_with("a/x.md")
      vp     = bundle.view_ports.build(path: "../outside")

      expect(vp).not_to be_valid
      expect(vp.errors[:path].join).to match(/escapes the bundle root/)
      expect(File.exist?(File.join(File.dirname(bundle.path), "outside"))).to be(false)
    end

    it "rejects a path escaping the bundle root and creates nothing, even with materialize" do
      bundle = bundle_with("a/x.md")
      vp     = bundle.view_ports.build(path: "../outside", materialize: true)

      expect(vp).not_to be_valid
      expect(vp.errors[:path].join).to match(/escapes the bundle root/)
      expect(File.exist?(File.join(File.dirname(bundle.path), "outside"))).to be(false)
    end

    it "treats the bundle root (empty path) as within the bundle" do
      bundle = bundle_with("a/x.md")
      vp     = bundle.view_ports.build(path: "")
      vp.valid?

      # FsNode's untouched `validates :path, presence: true` still rejects "" as
      # blank, so a root viewport isn't fully valid — but §5's containment check
      # must NOT be what fails it: the bundle root does not escape the bundle.
      expect(vp.errors[:path].join).not_to match(/escapes the bundle root/)
    end
  end

  describe "Bundle#ls" do
    it "builds an unsaved viewport to scope a query, running no validations and touching no disk" do
      bundle = bundle_with("a/x.md", "b/y.md")

      expect(bundle.ls("a").pluck(:path)).to contain_exactly("a/x.md")
      # nonexistent subdir: a build (not create) runs no validations and never mkpaths
      expect(bundle.ls("does-not-exist").to_a).to eq([])
      expect(File.exist?(File.join(bundle.path, "does-not-exist"))).to be(false)
    end
  end
end
