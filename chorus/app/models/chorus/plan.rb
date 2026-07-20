module Chorus
  # An OKF-backed markdown document an agent writes into its workspace's doc/ bundle
  # (plan 010 §5). The agent writes the file itself (the harness does not intercept
  # output); Chorus discovers the synced Concept and CLAIMS it by building the Plan
  # with it — ownership matters because Sync's owned-concept policy keys on
  # `owner_id.present?`, so an unowned plan concept would be disk-wins on every sync.
  #
  # Narrative content lives in the Concept (has_one_okf :concept), never a column
  # here — a body column would be a competing source of truth against the concept.
  class Plan < ApplicationRecord
    belongs_to :workspace
    belongs_to :agent
    has_one_okf :concept

    validates :name, presence: true
  end
end
