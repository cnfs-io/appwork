require "rails_helper"

# Appwork::Chorus::WorkOrder — a job against a site (plan 011 §4): a workable (its subject), a
# workspace (the place), a role (the requirement to execute it), and optionally the
# agent hired to fill it. It IS a document — has_one_okf :concept, no text column.
RSpec.describe Appwork::Chorus::WorkOrder, type: :model do
  it "has a valid factory" do
    expect(build(:appwork_chorus_work_order)).to be_valid
  end

  describe "validations (host-specified, fully or invalid — §5)" do
    it "requires a workable" do
      expect(build(:appwork_chorus_work_order, workable: nil)).not_to be_valid
    end

    it "requires a workspace" do
      expect(build(:appwork_chorus_work_order, workspace: nil)).not_to be_valid
    end

    it "requires a role" do
      expect(build(:appwork_chorus_work_order, role: nil)).not_to be_valid
    end

    it "does not require an agent (hiring may come later)" do
      expect(build(:appwork_chorus_work_order, agent: nil)).to be_valid
    end
  end

  describe "associations" do
    it "belongs to a polymorphic workable" do
      reflection = described_class.reflect_on_association(:workable)
      expect(reflection.macro).to eq(:belongs_to)
      expect(reflection.options[:polymorphic]).to be(true)
    end

    it "belongs to a workspace, a role, and (optionally) an agent" do
      expect(described_class.reflect_on_association(:workspace).macro).to eq(:belongs_to)
      expect(described_class.reflect_on_association(:role).macro).to eq(:belongs_to)
      expect(described_class.reflect_on_association(:agent).options[:optional]).to be(true)
    end

    it "is the request document — has_one_okf :concept" do
      reflection = described_class.reflect_on_association(:concept)
      expect(reflection.macro).to eq(:has_one)
      expect(reflection.options[:as]).to eq(:owner)
      expect(reflection.klass).to eq(Appwork::Okf::Concept)
    end

    it "has many plans and many results (as resultable)" do
      expect(described_class.reflect_on_association(:plans).macro).to eq(:has_many)
      results = described_class.reflect_on_association(:results)
      expect(results.macro).to eq(:has_many)
      expect(results.options[:as]).to eq(:resultable)
    end
  end

  # No competing source of truth against the OKF concept (010/011 boundary rule).
  it "carries no body/content/markdown column" do
    expect(described_class.column_names).not_to include("body", "content", "markdown")
  end
end
