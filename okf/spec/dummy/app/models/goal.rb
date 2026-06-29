class Goal < ApplicationRecord
  include Okf::Consumer
  belongs_to :strategy
  has_many :projects, dependent: :destroy
  owns_one_okf :concept
  delegate :title, :description, to: :concept, allow_nil: true
end
