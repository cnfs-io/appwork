require "rails_helper"

RSpec.describe Chorus::Taxonomy, type: :model do
  describe "validations" do
    it "has a valid factory" do
      expect(build(:chorus_taxonomy)).to be_valid
    end

    it "requires a name" do
      expect(build(:chorus_taxonomy, name: nil)).not_to be_valid
    end

    it "requires a slug" do
      expect(build(:chorus_taxonomy, slug: nil)).not_to be_valid
    end

    it "requires a unique slug" do
      create(:chorus_taxonomy, slug: "marketing")
      expect(build(:chorus_taxonomy, slug: "marketing")).not_to be_valid
    end
  end

  describe "the self-referential hierarchy" do
    it "links a child to its parent and back" do
      parent = create(:chorus_taxonomy, name: "Engineering", slug: "engineering")
      child = create(:chorus_taxonomy, name: "Ruby", slug: "ruby", parent: parent)

      expect(child.parent).to eq(parent)
      expect(parent.children).to contain_exactly(child)
    end

    it "allows a top-level category with no parent" do
      expect(create(:chorus_taxonomy).parent).to be_nil
    end

    it "nullifies children's parent_id when the parent is destroyed" do
      parent = create(:chorus_taxonomy)
      child = create(:chorus_taxonomy, parent: parent)
      parent.destroy
      expect(child.reload.parent_id).to be_nil
    end
  end

  describe "catalog association" do
    it "reaches catalog skills through the join" do
      tax = create(:chorus_taxonomy)
      skill = create(:chorus_catalog_skill)
      create(:chorus_skill_categorization, catalog_skill: skill, taxonomy: tax)
      expect(tax.reload.catalog_skills).to contain_exactly(skill)
    end
  end
end
