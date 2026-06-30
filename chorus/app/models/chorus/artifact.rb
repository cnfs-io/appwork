module Chorus
  class Artifact < ApplicationRecord
    belongs_to :workspace

    validates :name, presence: true
  end
end
