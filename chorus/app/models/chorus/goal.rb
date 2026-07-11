module Chorus
  class Goal < ApplicationRecord
    belongs_to :strategy
    has_many :projects, dependent: :destroy
    has_one_okf :concept

    validates :name, presence: true
  end
end
