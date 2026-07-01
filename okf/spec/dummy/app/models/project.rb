class Project < ApplicationRecord
  include CnfsOkf::Consumer
  belongs_to :goal
  has_many :issues, dependent: :destroy
  owns_one_cnfs_okf :concept
  delegate :title, :description, to: :concept, allow_nil: true
end
