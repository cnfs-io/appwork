# frozen_string_literal: true

require "rails_helper"

# The Appwork::Chorus::Workable concern — the contract a host model satisfies to become the
# SUBJECT of work (plan 011 §4). After the reshape the subject rides on WorkOrder,
# not Workspace (a place has no subject, a job does): a workable is addressed by many
# work orders through the polymorphic inverse. Exercised via WorkableDummy
# (chorus/spec/dummy). Being workable is concept-independent, so these specs build a
# bare dummy with no concept.
RSpec.describe Appwork::Chorus::Workable, type: :model do
  describe "the polymorphic work_orders inverse" do
    it "provides has_many :work_orders, as: :workable" do
      reflection = WorkableDummy.reflect_on_association(:work_orders)
      expect(reflection.macro).to eq(:has_many)
      expect(reflection.options[:as]).to eq(:workable)
      expect(reflection.klass).to eq(Appwork::Chorus::WorkOrder)
    end

    it "round-trips: a work order names the workable as its subject, reachable both ways" do
      dummy = WorkableDummy.create!(name: "W")
      work_order = create(:appwork_chorus_work_order, workable: dummy)

      expect(dummy.reload.work_orders).to contain_exactly(work_order)
      expect(work_order.reload.workable).to eq(dummy)
    end

    it "addresses many work orders over time" do
      dummy = WorkableDummy.create!(name: "W")
      a = create(:appwork_chorus_work_order, workable: dummy)
      b = create(:appwork_chorus_work_order, workable: dummy)

      expect(dummy.reload.work_orders).to contain_exactly(a, b)
    end

    it "nullify: destroying the workable leaves its durable work orders, detached" do
      dummy = WorkableDummy.create!(name: "W")
      work_order = create(:appwork_chorus_work_order, workable: dummy)

      dummy.destroy

      expect(Appwork::Chorus::WorkOrder.exists?(work_order.id)).to be(true)
      expect(work_order.reload.workable_id).to be_nil
    end
  end
end
