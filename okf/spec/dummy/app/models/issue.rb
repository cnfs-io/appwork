class Issue < ApplicationRecord
  include CnfsOkf::Consumer
  belongs_to :project
  owns_one_cnfs_okf :concept
  delegate :title, :description, to: :concept, allow_nil: true
end
