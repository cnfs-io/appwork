module Chorus
  class Agent < ApplicationRecord
    # Settled in 007 (001's open FK question): an Agent binds to one AgentAdapter
    # (its runtime). Optional so an unbound agent is legal; invocation resolves the
    # adapter through this association. Agent carries NO workspace FK — agent↔workspace
    # is discovered host-side.
    belongs_to :agent_adapter, optional: true

    has_one_okf :concept

    validates :name, presence: true
  end
end
