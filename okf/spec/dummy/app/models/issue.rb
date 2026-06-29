class Issue < ApplicationRecord
  include Okf::Consumer
  belongs_to :project
  owns_one_okf :concept
  delegate :title, :description, to: :concept, allow_nil: true
end
