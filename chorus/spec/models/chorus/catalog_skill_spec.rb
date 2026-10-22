require "rails_helper"

RSpec.describe Chorus::CatalogSkill, type: :model do
  describe "validations" do
    it "has a valid factory" do
      expect(build(:chorus_catalog_skill)).to be_valid
    end

    it "requires a resource" do
      skill = build(:chorus_catalog_skill, resource: nil)
      expect(skill).not_to be_valid
      expect(skill.errors[:resource]).to be_present
    end

    it "allows a null skill_name (a whole-repo entry)" do
      expect(build(:chorus_catalog_skill, :whole_repo)).to be_valid
    end
  end

  describe "the natural key [resource, skill_name]" do
    it "is unique" do
      create(:chorus_catalog_skill, resource: "acme/repo", skill_name: "a")
      dup = build(:chorus_catalog_skill, resource: "acme/repo", skill_name: "a")
      expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "distinguishes the same resource under different skill names" do
      create(:chorus_catalog_skill, resource: "acme/repo", skill_name: "a")
      expect(build(:chorus_catalog_skill, resource: "acme/repo", skill_name: "b").save!(validate: false)).to be_truthy
    end
  end

  describe "repo_topics" do
    it "round-trips a raw, un-normalized topic array (folksonomy, not taxonomy)" do
      skill = create(:chorus_catalog_skill, repo_topics: %w[ai Agents ruby-on-rails])
      expect(skill.reload.repo_topics).to eq(%w[ai Agents ruby-on-rails])
    end
  end

  describe "taxonomy association" do
    it "reaches taxonomies through the join" do
      skill = create(:chorus_catalog_skill)
      tax = create(:chorus_taxonomy)
      create(:chorus_skill_categorization, catalog_skill: skill, taxonomy: tax)
      expect(skill.reload.taxonomies).to contain_exactly(tax)
    end

    it "destroys its categorizations when destroyed (but not the taxonomy)" do
      cat = create(:chorus_skill_categorization)
      skill = cat.catalog_skill
      expect { skill.destroy }.to change(Chorus::SkillCategorization, :count).by(-1)
      expect(Chorus::Taxonomy.exists?(cat.taxonomy_id)).to be(true)
    end
  end

  describe "#curation (resolved on the natural key, not a FK)" do
    it "returns nil when chorus.org has rendered no verdict (row absent)" do
      skill = create(:chorus_catalog_skill, resource: "acme/repo", skill_name: "a")
      expect(skill.curation).to be_nil
    end

    it "finds the matching Curation row on [resource, skill_name]" do
      skill = create(:chorus_catalog_skill, resource: "acme/repo", skill_name: "a")
      curation = create(:chorus_curation, resource: "acme/repo", skill_name: "a", reputation: 42)
      expect(skill.curation).to eq(curation)
    end
  end
end
