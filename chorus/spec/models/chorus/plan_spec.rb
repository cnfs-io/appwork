require "rails_helper"

# Chorus::Plan — an OKF-backed markdown document an agent writes into its
# workspace's doc/ bundle (plan 010 §5). Model + migration only here; the Planner
# that populates it is a later step.
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

    it "requires a workspace" do
      plan = build(:chorus_plan, workspace: nil)
      expect(plan).not_to be_valid
    end

    it "requires an agent" do
      plan = build(:chorus_plan, agent: nil)
      expect(plan).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to a workspace" do
      expect(described_class.reflect_on_association(:workspace).macro).to eq(:belongs_to)
    end

    it "belongs to an agent" do
      expect(described_class.reflect_on_association(:agent).macro).to eq(:belongs_to)
    end

    it "owns its narrative content through has_one_okf :concept" do
      reflection = described_class.reflect_on_association(:concept)
      expect(reflection.macro).to eq(:has_one)
      expect(reflection.options[:as]).to eq(:owner)
      expect(reflection.klass).to eq(CnfsOkf::Concept)
    end
  end

  # No competing source of truth against the OKF concept (010 boundary rule).
  it "carries no body/content/markdown column" do
    expect(described_class.column_names).not_to include("body", "content", "markdown")
  end
end
