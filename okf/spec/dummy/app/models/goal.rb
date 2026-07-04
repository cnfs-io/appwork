class Goal < ApplicationRecord
  belongs_to :strategy

  has_many :projects, dependent: :destroy

  has_one_okf :concept

  delegate :title, :description, to: :concept, allow_nil: true
end
