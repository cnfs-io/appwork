require "rails_helper"

# A Role's durable, catalog-naive skill requirement — a skill named by stable
# identity, never an FK into the clobber-refreshed catalog (§4).
RSpec.describe Appwork::Chorus::SkillRequirement, type: :model do
  it "has a valid factory" do
    expect(build(:appwork_chorus_skill_requirement)).to be_valid
  end

  it "requires a name" do
    req = build(:appwork_chorus_skill_requirement, name: nil)
    expect(req).not_to be_valid
    expect(req.errors[:name]).to be_present
  end

  it "belongs to a role" do
    reflection = described_class.reflect_on_association(:role)
    expect(reflection.macro).to eq(:belongs_to)
  end

  it "is name-only — carries no catalog binding" do
    expect(described_class.reflect_on_association(:catalog_skill)).to be_nil
    expect(described_class.column_names).not_to include("catalog_skill_id")
  end

  it "is unique per [role, name]" do
    role = create(:appwork_chorus_role)
    create(:appwork_chorus_skill_requirement, role: role, name: "code-review")
    dup = build(:appwork_chorus_skill_requirement, role: role, name: "code-review")
    expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
