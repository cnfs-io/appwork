module Chorus
  class Role < ApplicationRecord
    belongs_to :organization

    has_many :agents, dependent: :nullify

    validates :name, presence: true
  end
end
