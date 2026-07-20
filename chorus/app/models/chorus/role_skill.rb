module Chorus
  # The AgentRole <-> Skill join (plan 010 §3). A real join model rather than HABTM
  # because attributes are likely (`required`, `position`, ordering) and adding them
  # later to a HABTM table means a migration AND a new model. Carries no attributes
  # yet beyond its two FKs; a role's skills are unique on the pair (DB-enforced).
  class RoleSkill < ApplicationRecord
    belongs_to :agent_role
    belongs_to :skill
  end
end
