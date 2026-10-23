require "rails_helper"
require "tmpdir"

# These specs assert the instrumentation added to the FsBundle / FsConcept
# concerns fires at the ActiveSupport::Notifications layer (the same layer
# partitia-telemetry subscribes to), independent of any OpenTelemetry SDK.
RSpec.describe "Appwork::Okf filesystem instrumentation" do
  # Capture every event published under `name` while the block runs.
  def capture_events(name)
    events = []
    callback = ->(*args) { events << ActiveSupport::Notifications::Event.new(*args) }
    ActiveSupport::Notifications.subscribed(callback, name) { yield }
    events
  end

  def write_md(dir, rel, frontmatter: nil, body: "hello\n")
    path = File.join(dir, rel)
    FileUtils.mkdir_p(File.dirname(path))
    content = frontmatter ? "---\n#{frontmatter}---\n#{body}" : body
    File.write(path, content)
    path
  end

  around do |example|
    Dir.mktmpdir("okf-instr") do |root|
      @root = root
      example.run
    end
  end

  describe "partitia_appwork.sync.run" do
    it "fires with reconciliation counts when the bundle path changes" do
      src = File.join(@root, "src")
      write_md(src, "alpha.md")
      bundle = Appwork::Okf::Bundle.create!(path: src)
      expect(bundle.concepts.pluck(:path)).to contain_exactly("alpha.md")

      # A brand-new directory (different inodes) forces a full reconciliation:
      # alpha.md disappears, beta.md appears.
      dest = File.join(@root, "dest")
      write_md(dest, "beta.md")

      events = capture_events("partitia_appwork.sync.run") do
        bundle.update!(path: dest)
      end

      expect(events.size).to eq(1)
      payload = events.first.payload
      expect(payload[:bundle_id]).to eq(bundle.id)
      expect(payload[:created]).to eq(1)
      expect(payload[:destroyed]).to eq(1)
      expect(payload[:skipped]).to eq(0)
      expect(bundle.reload.concepts.pluck(:path)).to contain_exactly("beta.md")
    end
  end

  describe "partitia_appwork.concept.persist" do
    it "fires when a frontmatter attribute changes and writes to disk" do
      src = File.join(@root, "bundle")
      write_md(src, "note.md", frontmatter: "title: Original\n")
      bundle = Appwork::Okf::Bundle.create!(path: src)
      concept = bundle.concepts.find_by!(path: "note.md")

      events = capture_events("partitia_appwork.concept.persist") do
        concept.update!(title: "Changed")
      end

      expect(events.size).to eq(1)
      payload = events.first.payload
      expect(payload[:concept_id]).to eq(concept.id)
      expect(payload[:path]).to eq("note.md")
      expect(payload[:bytes]).to be_a(Integer)
      expect(concept.pathname.read).to include("title: Changed")
    end
  end
end

RSpec.describe "no stray debugging breakpoints" do
  it "has no binding.pry left in app code" do
    root = Appwork::Okf::Engine.root.join("app")
    offenders = Dir.glob(root.join("**/*.rb")).select { |f| File.read(f).include?("binding.pry") }
    expect(offenders).to be_empty, "binding.pry found in: #{offenders.join(', ')}"
  end
end
