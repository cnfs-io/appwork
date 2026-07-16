module Chorus
  class Agent < ApplicationRecord
    has_one_okf :concept

    validates :name, presence: true
  end
end
