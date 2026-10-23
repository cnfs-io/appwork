module Appwork
  module Chorus
    # A ROLE — the requirement a piece of work carries, filled by hiring an Agent
    # against it (plan 011 §1). The role attaches to the WORK, not the worker: a
    # WorkOrder requires a role, an Agent is hired to fill it, and the Agent itself is
    # never permanently typed. When 004 evicted the org-position Role it was on the
    # grounds that IAM owned Role; IAM's Role has since narrowed to authorization (AAA)
    # only, so no collision remains and the defensive `AgentRole` prefix was dead
    # weight — the model is simply `Role` (plan 011 §1).
    #
    # A role is exactly three things (§3):
    #   - has_one_okf :concept — its charter (what a "project manager" IS), the corpus
    #     that feeds a system prompt;
    #   - has_many :skills, through :role_skills — the skills it carries;
    #   - long-lived and reused across many work orders — a stable catalog, not
    #     per-job config.
    # Nothing else yet.
    class Role < ApplicationRecord
      has_one_okf :concept          # the role's own definition doc (its charter)
      has_many :role_skills, dependent: :destroy
      has_many :skills, through: :role_skills

      validates :name, presence: true
    end
  end
end
