# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

# The DB->disk write path for a concept's markdown BODY (FsConcept#content=).
# Companion to concept_spec (derived reads) and sync_spec (disk->DB). These are
# the load-bearing assertions: get the staged-body precedence or the
# @pending_content reset wrong and you get intermittent content loss.
RSpec.describe "Appwork::Okf::Concept body write path" do
  def write_md(dir, rel, frontmatter: nil, body: "hello\n")
    path = File.join(dir, rel)
    FileUtils.mkdir_p(File.dirname(path))
    content = frontmatter ? "---\n#{frontmatter}---\n#{body}" : body
    File.write(path, content)
    path
  end

  around do |example|
    Dir.mktmpdir("okf-write") do |root|
      @root = root
      example.run
    end
  end

  # A bundle at @root/bundle holding one reconciled concept file.
  def concept_for(rel, **opts)
    dir = File.join(@root, "bundle")
    write_md(dir, rel, **opts)
    @bundle = Appwork::Okf::Bundle.create!(path: dir)
    @bundle.concepts.find_by!(path: rel)
  end

  def capture_events(name)
    events = []
    callback = ->(*args) { events << ActiveSupport::Notifications::Event.new(*args) }
    ActiveSupport::Notifications.subscribed(callback, name) { yield }
    events
  end

  describe "#content=" do
    it "writes the new body to disk with the original frontmatter block intact" do
      concept = concept_for("note.md", frontmatter: "title: Original\ntags:\n  - a\n")

      concept.content = "brand new body"
      concept.save!

      raw = concept.pathname.read
      expect(raw).to include("title: Original")
      expect(raw).to include("- a")
      expect(raw).to match(/---\n.*---\nbrand new body\n\z/m)
    end

    it "restamps content_hash to the new file bytes" do
      concept = concept_for("note.md", frontmatter: "title: Original\n")

      concept.content = "rewritten"
      concept.save!

      expect(concept.content_hash).to eq(Digest::MD5.hexdigest(concept.pathname.read))
    end

    it "normalises a missing trailing newline (textarea round-trip)" do
      concept = concept_for("note.md", frontmatter: "title: Original\n")

      concept.content = "no trailing newline"
      concept.save!

      expect(concept.pathname.read).to end_with("no trailing newline\n")
    end

    it "applies a body edit and a frontmatter edit in one save (single write)" do
      concept = concept_for("note.md", frontmatter: "title: Original\n")

      concept.content = "new body"
      concept.title = "Changed"

      events = capture_events("partitia_appwork.concept.persist") { concept.save! }

      expect(events.size).to eq(1)
      raw = concept.pathname.read
      expect(raw).to include("title: Changed")
      expect(raw).to end_with("new body\n")
    end

    it "returns the staged body before save (form re-render case)" do
      concept = concept_for("note.md", frontmatter: "title: Original\n", body: "old\n")

      concept.content = "staged"

      expect(concept.content).to eq("staged")
    end

    it "does not write the file when nothing changed" do
      concept = concept_for("note.md", frontmatter: "title: Original\n")

      real = concept.pathname
      allow(concept).to receive(:pathname).and_return(real)
      expect(real).not_to receive(:write)
      concept.save!
    end

    it "does not rewrite the file on a redundant re-save after a body edit" do
      concept = concept_for("note.md", frontmatter: "title: Original\n")
      concept.content = "edited"
      concept.save!

      # @pending_content cleared on the successful write, so this is a no-op.
      real = concept.pathname
      allow(concept).to receive(:pathname).and_return(real)
      expect(real).not_to receive(:write)
      concept.save!
    end

    it "fires partitia_appwork.concept.persist on a body-only edit" do
      concept = concept_for("note.md", frontmatter: "title: Original\n")

      events = capture_events("partitia_appwork.concept.persist") do
        concept.content = "body only"
        concept.save!
      end

      expect(events.size).to eq(1)
      expect(events.first.payload[:concept_id]).to eq(concept.id)
    end
  end

  describe "write failure" do
    it "aborts the save, leaves the DB unchanged, and preserves the staged body" do
      concept = concept_for("note.md", frontmatter: "title: Original\n")
      original_hash = concept.content_hash

      # `pathname` builds a fresh Pathname each call — pin it so the stub sticks,
      # letting read pass through while write raises.
      real = concept.pathname
      allow(concept).to receive(:pathname).and_return(real)
      allow(real).to receive(:write).and_raise(Errno::EACCES)

      concept.content = "will not land"

      # A halted around_save returns nil (not false); either way, falsy.
      expect(concept.save).to be_falsey
      expect(concept.reload.content_hash).to eq(original_hash)
      expect(concept.instance_variable_get(:@pending_content)).to eq("will not land")
    end
  end

  describe "without_persist (the Sync path)" do
    it "suppresses a staged body edit — no disk write" do
      concept = concept_for("note.md", frontmatter: "title: Original\n")
      before = concept.pathname.read

      concept.without_persist do
        concept.content = "should not reach disk"
        concept.save!
      end

      expect(concept.pathname.read).to eq(before)
    end

    it "suppresses the ident->save disk write that Sync performs" do
      concept = concept_for("note.md", frontmatter: "title: Original\n")

      expect(concept.pathname).not_to receive(:write)
      concept.without_persist do
        concept.ident
        concept.save!
      end
    end
  end

  describe "hash short-circuit terminates the sync loop" do
    it "a body edit followed by Sync.call reports unchanged, not updated" do
      concept = concept_for("note.md", frontmatter: "title: Original\n")

      concept.content = "edited via write path"
      concept.save!

      result = Appwork::Okf::Sync.call(bundle: @bundle)

      expect(result.unchanged).to eq(1)
      expect(result.updated).to eq(0)
    end
  end
end
