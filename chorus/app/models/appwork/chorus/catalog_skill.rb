module Appwork
  module Chorus
    # A local, refreshable MIRROR of a skill as it exists upstream (npx / skills.sh).
    # Truth lives upstream; this table is a cache we can join and query fast. It is
    # populated by the npx wrapper (Appwork::Chorus::SkillCatalog#ingest) from `find` /
    # `add --list` output.
    #
    # This is the tenant's view of the EXTERNAL catalog. It is a different noun from
    # Appwork::Chorus::Skill, which is the tenant's INTERNAL, OKF-backed skill (the harvested,
    # in-bundle artifact). The two are not conflated.
    #
    # Identity is the natural key [resource, skill_name] (skill_name nullable to
    # represent a whole-repo entry). Refresh discipline is mirror/clobber: a refresh
    # may reload rows, which is safe because nothing tenant-authored lives here.
    #
    # Account-scoped by tenancy (one physical DB per Account), so no owner column.
    class CatalogSkill < ApplicationRecord
      has_many :skill_categorizations, dependent: :destroy,
        inverse_of: :catalog_skill
      has_many :taxonomies, through: :skill_categorizations

      validates :resource, presence: true

      # chorus.org's verdict for this skill, resolved on the natural key rather than
      # a FK: Curation is a separate source on a separate cadence, so a CatalogSkill
      # may have no Curation row (nil = no verdict) and vice versa. Returns nil when
      # chorus.org has rendered no verdict — do NOT collapse that with reputation 0
      # (known bad); they answer opposite questions.
      def curation
        Curation.find_by(resource: resource, skill_name: skill_name)
      end
    end
  end
end
