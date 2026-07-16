module Chorus
  class Workspace < ApplicationRecord
    # A workspace occupies at most one workable at a time (a polymorphic target).
    # Chorus asserts nothing about what a workable IS yet; that is plan 005. Bare
    # seam here: column + association only.
    belongs_to :workable, polymorphic: true, optional: true

    has_many :artifacts, dependent: :destroy

    validates :name, presence: true
  end
end
