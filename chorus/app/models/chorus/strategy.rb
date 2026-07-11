module Chorus
  class Strategy < ApplicationRecord
    has_many :goals, dependent: :destroy
    has_many :projects, through: :goals #, dependent: :destroy
    has_one_okf :concept
    has_many_okf :view_ports

    validates :name, presence: true
  end
end
