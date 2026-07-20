module Chorus
  # A CAPABILITY LOADOUT — the equipment an agent takes on to execute a job, NOT an
  # org-chart position. (The org-position Role deleted in 004 was reporting
  # lines/ownership; it correctly left for micro_manager/IAM.) A role has skills and
  # a charter, and nothing else yet — the earlier "skills + view_ports + corpus
  # window" framing (plan 007) was speculative and is scaled back (plan 010 §2).
  # Named AgentRole, not Role: a host app may have IAM::Role in scope and the
  # ambiguity is worse than the stutter in `agent.agent_role`.
  #
  #   - has_one_okf :concept — the role's OWN self-definition (its charter; what a
  #     "project manager" IS), the corpus that will feed a system prompt.
  #   - has_many :skills, through :role_skills — the skills this role equips.
  class AgentRole < ApplicationRecord
    has_one_okf :concept          # the role's own definition doc (its charter)
    has_many :role_skills, dependent: :destroy
    has_many :skills, through: :role_skills

    validates :name, presence: true
  end
end
