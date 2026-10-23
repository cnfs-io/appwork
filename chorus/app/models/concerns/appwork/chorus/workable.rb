module Appwork
  module Chorus
    # The participation contract a host domain model satisfies to become the subject
    # of work. A host `include`s this exactly as it `include`s Appwork::Okf::Consumer —
    # openly, as a declared Chorus consumer. Chorus stays naive of what the workable IS
    # (a Strategy, Goal, Project, Ticket, a bare Concept-backed node); it sees only
    # this contract.
    #
    # Occupiability ONLY. Status is a separate, orthogonal concern: every spine node
    # declares `okf_frontmatter :status` (an OKF-consumer facility) independent of
    # whether it is workable, so status does NOT ride on Workable. Being workable does
    # not require a concept. See ADR 0001 (status-event-sourcing).
    #
    # A workable is addressed by WorkOrders (plan 011 §4) — the request that lands
    # against a place carries the subject. (Before the reshape the subject rode on the
    # Workspace; a place has no subject, a job does.)
    module Workable
      extend ActiveSupport::Concern

      included do
        # Polymorphic inverse of Appwork::Chorus::WorkOrder#workable — every work order that has
        # named this thing as its subject. (This class_name is Chorus naming its OWN
        # class — not a cross-gem reference.)
        has_many :work_orders, as: :workable, class_name: "Appwork::Chorus::WorkOrder",
          dependent: :nullify
      end
    end
  end
end
