class Project < ApplicationRecord
  belongs_to :goal
  has_many :issues, dependent: :destroy

  has_one_okf :concept

  delegate :title, :description, to: :concept, allow_nil: true
end
