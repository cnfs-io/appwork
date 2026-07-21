module Chorus
  # A job against a site (plan 011 §4). A feature request that lands against a
  # Workspace, carrying the Role required to execute it; an Agent is hired to fill
  # that role. The WorkOrder reads the workable and (via #execute!, added in step 7)
  # produces Plans and Results.
  #
  # A WorkOrder is a DOCUMENT: in practice Claude Desktop writes it — a summary of a
  # design conversation, landing as markdown in the workspace's viewport — and the
  # row is created pointing at it. That is why it carries a concept (has_one_okf
  # :concept) rather than a text column.
  #
  # The role attaches to the WORK, not the worker (§1): `role` is what's needed to
  # EXECUTE this order. Its Plans each carry their OWN role (whom the architect
  # addresses the plan to), distinct from this one — delegation, not denormalization.
  #
  # Everything the host decides arrives fully specified (§5): a work order names its
  # workable, workspace, role, and (optionally) agent, or it is invalid. Chorus
  # builds no triage, hiring, or defaulting this phase.
  class WorkOrder < ApplicationRecord
    belongs_to :workable, polymorphic: true
    belongs_to :workspace
    belongs_to :role
    belongs_to :agent, optional: true

    has_one_okf :concept                             # the request itself, as markdown

    has_many :plans, dependent: :destroy
    has_many :results, as: :resultable, dependent: :destroy
  end
end
