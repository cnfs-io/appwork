module Chorus
  # An OKF-backed markdown document an agent writes, addressed to a role (plan 011
  # §7). The agent writes the file itself (the harness does not intercept output);
  # Chorus discovers the synced Concept and CLAIMS it by building the Plan with it —
  # ownership matters because Sync's owned-concept policy keys on `owner_id.present?`,
  # so an unowned plan concept would be disk-wins on every sync.
  #
  # `plan.role` is WHO SHOULD EXECUTE IT — set by the level above (a WorkOrder's
  # architect addresses the plan to the SWE who will execute it), and distinct from
  # `work_order.role`. That is delegation, not denormalization.
  #
  # Narrative content lives in the Concept (has_one_okf :concept), never a column
  # here — a body column would be a competing source of truth against the concept.
  #
  # TRANSITIONAL (plan 011 §7): `work_order`/`role` are optional and `workspace` is
  # still carried, because Chorus::Planner (deleted in step 7) still creates Plans by
  # workspace. When execute! replaces the Planner, work_order/role become the
  # required spine and `workspace` drops (reached via `work_order.workspace`).
  class Plan < ApplicationRecord
    belongs_to :work_order, optional: true
    belongs_to :role, optional: true              # WHO SHOULD EXECUTE IT
    belongs_to :agent, optional: true
    belongs_to :workspace, optional: true         # transitional — drops in step 7

    has_one_okf :concept
    has_many :results, as: :resultable, dependent: :destroy

    validates :name, presence: true
  end
end
