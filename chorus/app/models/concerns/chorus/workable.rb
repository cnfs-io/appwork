module Chorus
  # The participation contract a host domain model satisfies to be occupiable by
  # a Chorus::Workspace. A host `include`s this exactly as it `include`s
  # CnfsOkf::Consumer — openly, as a declared Chorus consumer. Chorus stays naive
  # of what the workable IS (a Strategy, Goal, Project, Ticket, a bare
  # Concept-backed node); it sees only this contract.
  #
  # Occupiability ONLY. Status is a separate, orthogonal concern: every spine node
  # declares `okf_frontmatter :status` (an OKF-consumer facility) independent of
  # whether it is occupiable, so status does NOT ride on Workable. Occupiability
  # does not require a concept. See ADR 0001 (status-event-sourcing).
  module Workable
    extend ActiveSupport::Concern

    included do
      # Polymorphic inverse of Chorus::Workspace#workable. A workable is occupied
      # by at most one workspace at a time. (This class_name is Chorus naming its
      # OWN class — not a cross-gem reference.)
      has_one :workspace, as: :workable, class_name: "Chorus::Workspace",
        dependent: :nullify
    end
  end
end
