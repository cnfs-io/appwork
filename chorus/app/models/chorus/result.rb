module Chorus
  # ONE row per invocation (plan 011 §8): a narrow, durable record of what a single
  # run did and what it cost. Polymorphic over its `resultable` — a WorkOrder or a
  # Plan today (a Task in Phase 2).
  #
  # This is a REWRITE of the old Result, not a rename. The former model was one
  # durable ActiveModel::Errors-shaped accumulator per *thing*, designed to stay open
  # for later contributors (add/merge/full_messages/success?). Per *invocation* that
  # shape is unnecessary: a run happened once, so its cost/usage/outcome are plain
  # columns and a retry is simply a SECOND Result. "Did this Plan succeed?" is a
  # question about `plan.results` collectively, not one row — which is what makes
  # attempt history honest and gives retry a home. `messages` survives only as a
  # plain json diagnostics bag.
  #
  # An Artifact is something a run PRODUCED, so the FK inverted: Artifact belongs_to
  # :result (was Result belongs_to :artifact).
  class Result < ApplicationRecord
    belongs_to :resultable, polymorphic: true

    has_many :artifacts, dependent: :nullify

    after_initialize do
      self.argv     ||= []
      self.messages ||= {}
    end
  end
end
