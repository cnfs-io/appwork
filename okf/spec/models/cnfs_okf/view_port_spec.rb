# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

# ViewPort had zero direct coverage. Exercises the LIKE-based concept scoping,
# the directory validation, and #tree against real files in a tmpdir.
RSpec.describe CnfsOkf::ViewPort do
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
    CnfsOkf::Bundle.create!(path: dir)
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
end
