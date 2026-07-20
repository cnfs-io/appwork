module Chorus
  class Skill < ApplicationRecord
    # A skill is a concept for now (whether some skills are better modeled as
    # view_ports is deferred — plan 010 §3). Equipped onto roles through the
    # RoleSkill join; the org-position Role left Chorus in 004, so nothing owns a
    # Skill from an org spine.
    has_one_okf :concept
    has_many :role_skills, dependent: :destroy
    has_many :agent_roles, through: :role_skills

    validates :name, presence: true
  end
end
