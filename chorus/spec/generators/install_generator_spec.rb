require "rails_helper"
require "rails/generators"
require "generators/appwork/chorus/install/install_generator"

RSpec.describe Appwork::Chorus::Generators::InstallGenerator do
  let(:root) { Pathname.new(Dir.mktmpdir) }

  after { FileUtils.rm_rf(root) }

  def run_generator
    out = StringIO.new
    original = $stdout
    $stdout = out
    described_class.start([], destination_root: root.to_s)
    out.string
  ensure
    $stdout = original
  end

  def snapshot = Dir.glob(root.join("**/*")).sort.to_h { |f| [ f, File.file?(f) ? File.read(f) : nil ] }

  it "is namespaced appwork:chorus:install" do
    expect(described_class.namespace).to eq("appwork:chorus:install")
  end

  context "when database.yml reads the registry" do
    before do
      FileUtils.mkdir_p(root.join("config"))
      File.write(root.join("config/database.yml"),
                 "default:\n  migrations_paths: <%= Partitia::Support.migrations_paths[:primary] %>\n")
    end

    it "says so, prints what is left, and changes nothing on a second run" do
      first = run_generator
      before_second = snapshot
      second = run_generator

      expect(first).to include("reads Partitia::Support.migrations_paths")
      expect(first).to include("appwork-chorus installed. Still to do:")
      expect(first).not_to include("partitia:support:install")
      expect(snapshot).to eq(before_second)
      expect(second).to eq(first)
    end
  end

  context "when database.yml does not read the registry" do
    it "points at partitia:support:install" do
      expect(run_generator).to include("partitia:support:install")
    end
  end
end
