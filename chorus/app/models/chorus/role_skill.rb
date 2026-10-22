module Chorus
  # The Role <-> Skill join (plan 010 §3). A real join model rather than HABTM
  # because attributes are likely (`required`, `position`, ordering) and adding them
  # later to a HABTM table means a migration AND a new model. Carries no attributes
  # yet beyond its two FKs; a role's skills are unique on the pair (DB-enforced).
  class RoleSkill < ApplicationRecord
    belongs_to :role
    belongs_to :skill
  end
end
