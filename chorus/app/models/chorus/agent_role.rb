module Chorus
  # An ORG ROLE — the HR-shaped job a participant holds ("project manager", "swe"),
  # with a charter and skills. When 004 evicted the org-position Role it was on the
  # grounds that IAM owned Role; IAM's Role has since narrowed to authorization
  # (AAA) only, so the HR-shaped role had no home and belongs here (plan 010 §1). It
  # is what `Agent belongs_to`. Named AgentRole, not Role: a host app may have
  # IAM::Role in scope and the ambiguity is worse than the stutter in
  # `agent.agent_role`.
  #
  #   - has_one_okf :concept — the role's charter (what a "project manager" IS), the
  #     corpus that will feed a system prompt.
  #   - has_many :skills, through :role_skills — the skills this role carries.
  #
  # A role has a charter and skills, and nothing else yet: the earlier "capability
  # loadout" framing (skills + view_ports + corpus window, plan 007) was speculative
  # and is scaled back (plan 010 §2).
  class AgentRole < ApplicationRecord
    has_one_okf :concept          # the role's own definition doc (its charter)
    has_many :role_skills, dependent: :destroy
    has_many :skills, through: :role_skills

    validates :name, presence: true
  end
end
