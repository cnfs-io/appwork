module Appwork
  module Chorus
    # A first-class, queryable category dimension. NOT owned by curation and NOT
    # owned by the catalog — it stands alone, is referred to by whoever needs to
    # categorize or search, and (in a later plan) is morphed from OKF Concepts,
    # reconciled against the stable `slug`.
    #
    # Refresh discipline is morph/durable: unlike CatalogSkill and Curation, taxonomy
    # has CONTINUITY — categories persist across scans and accumulate associations.
    #
    # `parent_id` allows a shallow area -> sub-category hierarchy IF wanted. The
    # column and the self-association are modeled now; no hierarchy logic is built
    # beyond that.
    #
    # # 004 deferred: the Concept -> Taxonomy scan (the job that morphs this table
    # from the OKF Bundle) lands in a later plan. For now the table is hand-seeded.
    class Taxonomy < ApplicationRecord
      belongs_to :parent, class_name: "Appwork::Chorus::Taxonomy", optional: true,
        inverse_of: :children
      has_many :children, class_name: "Appwork::Chorus::Taxonomy",
        foreign_key: :parent_id, inverse_of: :parent, dependent: :nullify

      has_many :skill_categorizations, dependent: :destroy,
        inverse_of: :taxonomy
      has_many :catalog_skills, through: :skill_categorizations

      validates :name, presence: true
      validates :slug, presence: true, uniqueness: true
    end
  end
end
