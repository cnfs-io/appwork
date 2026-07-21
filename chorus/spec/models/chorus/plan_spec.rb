require "rails_helper"

# Chorus::Plan — an OKF-backed markdown document addressed to a role, under a
# WorkOrder (plan 011 §7). `plan.role` is who should EXECUTE it, distinct from
# `work_order.role`.
#
# TRANSITIONAL: work_order/role are optional and `workspace` is still carried while
# Chorus::Planner (deleted in step 7) creates Plans by workspace; execute! makes
# work_order/role the required spine and drops workspace.
RSpec.describe Chorus::Plan, type: :model do
  it "has a valid factory" do
    expect(build(:chorus_plan)).to be_valid
  end

  describe "validations" do
    it "requires a name" do
      plan = build(:chorus_plan, name: nil)
      expect(plan).not_to be_valid
      expect(plan.errors[:name]).to be_present
    end
  end

  describe "associations" do
    it "belongs to a work_order" do
      expect(described_class.reflect_on_association(:work_order).macro).to eq(:belongs_to)
    end

    it "belongs to a role — who should execute it (§7)" do
      expect(described_class.reflect_on_association(:role).macro).to eq(:belongs_to)
    end

    it "belongs to an agent (optional)" do
      expect(described_class.reflect_on_association(:agent).options[:optional]).to be(true)
    end

    it "has many results, as resultable" do
      reflection = described_class.reflect_on_association(:results)
      expect(reflection.macro).to eq(:has_many)
      expect(reflection.options[:as]).to eq(:resultable)
    end

    it "owns its narrative content through has_one_okf :concept" do
      reflection = described_class.reflect_on_association(:concept)
      expect(reflection.macro).to eq(:has_one)
      expect(reflection.options[:as]).to eq(:owner)
      expect(reflection.klass).to eq(CnfsOkf::Concept)
    end

    it "reaches its workspace through the work order (§7)" do
      plan = create(:chorus_plan)
      expect(plan.work_order.workspace).to be_a(Chorus::Workspace)
    end
  end

  # No competing source of truth against the OKF concept (010 boundary rule).
  it "carries no body/content/markdown column" do
    expect(described_class.column_names).not_to include("body", "content", "markdown")
  end
end
