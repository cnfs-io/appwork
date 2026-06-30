module Chorus
  class Strategy < ApplicationRecord
    include Okf::ConsumesConcept

    belongs_to :organization

    has_many :goals, dependent: :destroy

    validates :name, presence: true
  end
end
