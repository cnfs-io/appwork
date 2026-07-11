module Chorus
  class Role < ApplicationRecord
    has_many :agents, dependent: :nullify

    validates :name, presence: true
  end
end
