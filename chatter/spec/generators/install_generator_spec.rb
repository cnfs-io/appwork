require "rails_helper"
require "tmpdir"
require "generators/appwork/chatter/install/install_generator"

RSpec.describe Appwork::Chatter::Generators::InstallGenerator do
  around do |example|
    Dir.mktmpdir { |dir| @dir = dir; example.run }
  end

  def run_generator
    described_class.start([], destination_root: @dir, shell: Thor::Base.shell.new)
  end

  def read(rel) = File.read(File.join(@dir, rel))

  def scaffold_app
    FileUtils.mkdir_p(File.join(@dir, "config"))
    File.write(File.join(@dir, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
  end

  before { scaffold_app }

  it "mounts the engine in the host routes" do
    run_generator
    expect(read("config/routes.rb")).to include(%(mount Appwork::Chatter::Engine => "/chatter"))
  end

  it "is namespaced appwork:chatter:install" do
    expect(described_class.namespace).to eq("appwork:chatter:install")
  end

  it "prints the entry point and what the host still has to do" do
    out = capture_stdout { run_generator }
    expect(out).to include('appwork-chatter installed at /chatter')
    expect(out).to include("Appwork::Chatter.parent_controller")
    expect(out).to include("partitia:support:install")
  end

  it "does not point at partitia:support:install once database.yml reads the registry" do
    File.write(File.join(@dir, "config/database.yml"),
               "default:\n  migrations_paths: <%= Partitia::Support.migrations_paths[:primary] %>\n")
    expect(capture_stdout { run_generator }).not_to include("partitia:support:install")
  end

  def capture_stdout
    out = StringIO.new
    original = $stdout
    $stdout = out
    yield
    out.string
  ensure
    $stdout = original
  end

  it "is safe to re-run — no duplicate mount line" do
    run_generator
    run_generator
    routes = read("config/routes.rb")
    expect(routes.scan(%(mount Appwork::Chatter::Engine)).size).to eq(1)
  end
end
