module Chorus
  class AgentProfile < ApplicationRecord
    # belongs_to :role, optional: true
    has_many :agents, dependent: :nullify
    has_one_okf :concept

    validates :name, presence: true
  end
end
