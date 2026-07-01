class Goal < ApplicationRecord
  include CnfsOkf::Consumer
  belongs_to :strategy
  has_many :projects, dependent: :destroy
  owns_one_cnfs_okf :concept
  delegate :title, :description, to: :concept, allow_nil: true
end
