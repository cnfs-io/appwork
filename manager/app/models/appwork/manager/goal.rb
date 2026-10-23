module Appwork
  module Manager
    class Goal < ApplicationRecord
      belongs_to :strategy
      has_many :projects, dependent: :destroy
      has_one_okf :concept
      okf_frontmatter :status
      include Appwork::Chorus::Workable

      validates :name, presence: true
    end
  end
end
