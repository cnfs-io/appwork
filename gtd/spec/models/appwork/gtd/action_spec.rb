# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

# Tier 1 gate (Plan 012): prove Appwork::Gtd::Action wears all THREE hats before any board
# exists. This is the composition root (ADR 0005) — content owner (010), placement
# subject (011), assertion honorer (0006) — unit-tested in isolation.
#
# The content half uses real files in a tmpdir, matching okf/note house style.
RSpec.describe Appwork::Gtd::Action do
  def write_md(dir, rel, title:, body:)
    path = File.join(dir, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "---\ntitle: #{title}\n---\n#{body}")
    path
  end

  around do |example|
    Dir.mktmpdir("gtd-action") do |root|
      @root = root
      example.run
    end
  end

  # An Action owning a concept backed by a real .md at @root/gtd/<rel>.
  def action_for(title:, body:, rel: "actions/call-bank.md")
    dir = File.join(@root, "gtd")
    write_md(dir, rel, title:, body:)
    bundle = Appwork::Okf::Bundle.create!(path: dir)
    Appwork::Gtd::Action.create!(status: "inbox").tap do |action|
      action.update!(concept: bundle.concepts.find_by!(path: rel))
    end
  end

  # --- Hat 1: content interface (010 / ADR 0005) ----------------------------
  describe "the content interface (owns an OKF concept)" do
    it "#title returns the concept's frontmatter title" do
      action = action_for(title: "Call the bank", body: "ask about the wire\n")

      expect(action.title).to eq("Call the bank")
    end

    it "#body returns the markdown body with the frontmatter block stripped" do
      action = action_for(title: "T", body: "step one\nstep two\n")

      expect(action.body).to eq("step one\nstep two\n")
      expect(action.body).not_to include("title:")
      expect(action.body).not_to include("---")
    end

    describe "#update_content" do
      it "writes the new body to disk, frontmatter block intact" do
        action = action_for(title: "Keep me", body: "old body\n")
        concept = action.concept

        action.update_content(body: "brand new body\n")

        raw = concept.pathname.read
        expect(raw).to include("brand new body")
        expect(raw).not_to include("old body")
        expect(raw).to match(/\A---\r?\n.*title: Keep me.*\r?\n---\r?\n/m)
      end

      it "round-trips: re-reading the body reflects the edit" do
        action = action_for(title: "T", body: "before\n")

        action.update_content(body: "after\n")

        expect(action.reload.body).to eq("after\n")
      end

      it "goes through OKF's single write path (assignment alone writes nothing)" do
        action = action_for(title: "T", body: "unwritten\n")
        concept = action.concept
        before = concept.pathname.read

        concept.content = "staged but not saved"

        expect(concept.pathname.read).to eq(before)
      end
    end
  end

  # --- Hat 2: placement subject (011 / ADR 0005) ----------------------------
  describe "as a placement subject (appears on boards via placements)" do
    it "has_many placements polymorphically, and multi-board is free" do
      action = Appwork::Gtd::Action.create!(status: "inbox")
      workflow = Partitia::Ui::Board.create!(name: "Workflow")
      context  = Partitia::Ui::Board.create!(name: "Context")
      next_col = workflow.columns.create!(name: "Next")
      home_col = context.columns.create!(name: "@home")

      p1 = next_col.placements.create!(subject: action)
      p2 = home_col.placements.create!(subject: action)

      # One Action -> two placements, independent rows on independent boards
      # (ADR 0005: the same subject appears on N boards for free).
      expect(action.placements).to contain_exactly(p1, p2)
      expect(p1.subject_type).to eq("Appwork::Gtd::Action")
      expect(p1.column).not_to eq(p2.column)
    end

    it "destroys its placements when the action is destroyed" do
      action = Appwork::Gtd::Action.create!(status: "inbox")
      col = Partitia::Ui::Board.create!(name: "B").columns.create!(name: "C")
      col.placements.create!(subject: action)

      expect { action.destroy }.to change(Partitia::Ui::Placement, :count).by(-1)
    end
  end

  # --- Hat 3: assertion honorer, GUARDED (011 / ADR 0006) -------------------
  # Stricter than Note's naive `update!(attribute => value)`: only `:status` (the
  # sole thing any column in this spike asserts) is honored; an unexpected
  # attribute is a SAFE NO-OP, never a blind column write.
  describe "#satisfy_assertion (guarded)" do
    it "honors an asserted :status by writing the status column" do
      action = Appwork::Gtd::Action.create!(status: "inbox")

      action.satisfy_assertion(attribute: :status, value: "done")

      expect(action.reload.status).to eq("done")
    end

    it "treats an unexpected asserted attribute as a safe no-op" do
      action = Appwork::Gtd::Action.create!(status: "inbox")

      expect {
        action.satisfy_assertion(attribute: :context, value: "anything")
      }.not_to raise_error

      # No blind write: status is untouched and nothing about the action changed.
      expect(action.reload.status).to eq("inbox")
      expect(action.saved_changes?).to be(false)
    end
  end
end
