require "rails_helper"

RSpec.describe Appwork::Chorus::SkillCategorization, type: :model do
  it "has a valid factory" do
    expect(build(:appwork_chorus_skill_categorization)).to be_valid
  end

  it "belongs to a catalog skill and a taxonomy" do
    cat = create(:appwork_chorus_skill_categorization)
    expect(cat.catalog_skill).to be_a(Appwork::Chorus::CatalogSkill)
    expect(cat.taxonomy).to be_a(Appwork::Chorus::Taxonomy)
  end

  it "is unique on [catalog_skill_id, taxonomy_id]" do
    skill = create(:appwork_chorus_catalog_skill)
    tax = create(:appwork_chorus_taxonomy)
    create(:appwork_chorus_skill_categorization, catalog_skill: skill, taxonomy: tax)

    dup = build(:appwork_chorus_skill_categorization, catalog_skill: skill, taxonomy: tax)
    expect(dup).not_to be_valid
    expect(dup.errors[:catalog_skill_id]).to be_present
  end

  it "allows the same skill under a different taxonomy" do
    skill = create(:appwork_chorus_catalog_skill)
    create(:appwork_chorus_skill_categorization, catalog_skill: skill, taxonomy: create(:appwork_chorus_taxonomy))
    expect(build(:appwork_chorus_skill_categorization, catalog_skill: skill, taxonomy: create(:appwork_chorus_taxonomy))).to be_valid
  end
end
