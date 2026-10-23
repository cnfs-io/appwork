module MicroManager
  class Strategy < ApplicationRecord
    has_many :goals, dependent: :destroy
    has_many :projects, through: :goals
    has_one_okf :concept
    has_many_okf :view_ports
    okf_frontmatter :status
    include Chorus::Workable

    validates :name, presence: true
  end
end
