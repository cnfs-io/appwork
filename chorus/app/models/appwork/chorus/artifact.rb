module Appwork
  module Chorus
    # Something a run produced (plan 011 §8). The FK inverted this phase: an artifact
    # belongs to the Result that produced it (was Result belongs_to :artifact).
    # Otherwise untouched — first-class, type-open `kind`, a free-form `locator`;
    # Chorus special-cases no artifact kind. STI / GitCommit / source FK are Phase 2.
    class Artifact < ApplicationRecord
      belongs_to :result, optional: true

      validates :name, presence: true
    end
  end
end
