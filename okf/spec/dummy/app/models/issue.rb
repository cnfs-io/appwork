class Issue < ApplicationRecord
  belongs_to :project

  has_one_okf :concept

  delegate :title, :description, to: :concept, allow_nil: true
end
