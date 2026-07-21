# frozen_string_literal: true

require "rails_helper"

# The Chorus::Workable concern — OCCUPIABILITY ONLY (006 moved status out to
# `okf_frontmatter :status` on each host spine model). Exercised via WorkableDummy
# (chorus/spec/dummy). Occupiability is concept-independent, so these specs build a
# bare dummy with no concept.
RSpec.describe Chorus::Workable, type: :model do
  describe "occupancy (the polymorphic workspace inverse)" do
    it "round-trips: a workspace occupies the workable, reachable both ways" do
      dummy = WorkableDummy.create!(name: "W")
      workspace = Chorus::Workspace.create!(name: "Delivery", workable: dummy, role: create(:chorus_role))

      expect(dummy.reload.workspace).to eq(workspace)
      expect(workspace.reload.workable).to eq(dummy)
    end

    it "releases (workspace goes nil) when the occupying workspace is destroyed" do
      dummy = WorkableDummy.create!(name: "W")
      workspace = Chorus::Workspace.create!(name: "Delivery", workable: dummy, role: create(:chorus_role))

      workspace.destroy

      expect(dummy.reload.workspace).to be_nil
      expect(WorkableDummy.exists?(dummy.id)).to be(true)
    end

    it "nullify: destroying the workable leaves the durable workspace, detached" do
      dummy = WorkableDummy.create!(name: "W")
      workspace = Chorus::Workspace.create!(name: "Delivery", workable: dummy, role: create(:chorus_role))

      dummy.destroy

      expect(Chorus::Workspace.exists?(workspace.id)).to be(true)
      expect(workspace.reload.workable_id).to be_nil
    end
  end
end
