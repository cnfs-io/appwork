module Chorus
  class Agent < ApplicationRecord
    include Okf::ConsumesConcept

    belongs_to :organization
    belongs_to :role, optional: true

    has_many :issues, dependent: :nullify

    validates :name, presence: true
  end
end
