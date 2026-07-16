module Chorus
  # The bare CatalogSkill <-> Taxonomy join (many-to-many). v1 is exactly two FKs
  # and a unique pair index.
  #
  # # 004 deferred: taxonomy-assignment provenance — whether a tag flows THROUGH
  # curation (chorus.org tags it) or is assigned independently (so an uncurated
  # skill can still be tagged) — is a policy question that decides one-join-vs-two.
  # It is parked; do NOT add an `assigned_by`/source column here yet.
  class SkillCategorization < ApplicationRecord
    belongs_to :catalog_skill, class_name: "Chorus::CatalogSkill",
      inverse_of: :skill_categorizations
    belongs_to :taxonomy, class_name: "Chorus::Taxonomy",
      inverse_of: :skill_categorizations

    validates :catalog_skill_id, uniqueness: { scope: :taxonomy_id }
  end
end
