module Chorus
  # A Role's durable, catalog-naive skill requirement: a skill named by STABLE
  # identity (`name`, optional `slug`), NOT an FK into the clobber-refreshed
  # CatalogSkill. This keeps the role's SPECIFICATION ("a Reviewer needs
  # code-review") separate from the volatile RESOLUTION ("which catalog row
  # satisfies that right now"), which Chorus::SkillResolver performs at equip time
  # (§4). Name-only on purpose — a catalog refresh must never break a Role.
  class SkillRequirement < ApplicationRecord
    belongs_to :agent_role

    validates :name, presence: true
  end
end
