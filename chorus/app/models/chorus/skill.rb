module Chorus
  class Skill < ApplicationRecord
    # belongs_to :role, optional: true
    # has_many :issues, dependent: :nullify
    has_one_okf :concept

    validates :name, presence: true
  end
end
