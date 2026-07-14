class Goal < ApplicationRecord
  belongs_to :strategy

  has_one_okf :concept

  delegate :title, :description, to: :concept, allow_nil: true
end
