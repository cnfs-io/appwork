module Chorus
  # A CAPABILITY LOADOUT — the equipment an agent takes on to execute a job, NOT an
  # org-chart position. (The org-position Role deleted in 004 was reporting
  # lines/ownership; it correctly left for micro_manager/IAM.) "Reviewer" =
  # {review-skill, rubric-reading-skill} + a domain-knowledge window. Role belongs
  # in Chorus because it is about equipping an agent to execute, not org structure.
  #
  # Two distinct OKF bindings, two jobs (both present, not either/or):
  #   - has_one_okf :concept   — the role's OWN self-definition (its charter; what a
  #                              Reviewer IS), same as Agent/Skill carry a concept.
  #   - has_many_okf :view_ports — the role's DOMAIN-KNOWLEDGE windows; a ViewPort
  #                              scopes a subtree of an OKF bundle and yields its
  #                              concepts (the corpus slice this role reads).
  #
  # Role does NOT belongs_to :source and does NOT FK into CatalogSkill: domain
  # knowledge is OKF ADDRESSING (ViewPort), not a source FK; and skills are named by
  # stable identity (SkillRequirement), resolved to catalog rows at equip time by
  # Chorus::SkillResolver (§4). Catalog-naive and org-naive by construction.
  class Role < ApplicationRecord
    has_one_okf  :concept          # the role's own definition doc (its charter)
    has_many_okf :view_ports       # the role's domain windows (corpus slices it reads)
    has_many :skill_requirements, dependent: :destroy

    validates :name, presence: true
  end
end
