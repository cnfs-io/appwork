module Chorus
  class Agent < ApplicationRecord
    # Settled in 007 (001's open FK question): an Agent binds to one AgentProfile
    # (its runtime). Optional so an unbound agent is legal; invocation resolves the
    # profile through this association. Agent carries NO workspace FK and no Role —
    # agent↔workspace is discovered host-side, and IAM owns Role.
    belongs_to :agent_profile, optional: true

    has_one_okf :concept

    validates :name, presence: true
  end
end
