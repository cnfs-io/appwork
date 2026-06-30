module Chorus
  class Goal < ApplicationRecord
    include Okf::ConsumesConcept

    belongs_to :strategy
    has_one :organization, through: :strategy

    has_many :projects, dependent: :destroy

    validates :name, presence: true
  end
end
