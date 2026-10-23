module Appwork
  module Manager
    class Project < ApplicationRecord
      belongs_to :goal
      has_one :strategy, through: :goal

      # A Project is a Chorus workable (occupiable by a Appwork::Chorus::Workspace) that
      # carries an opaque status in its OKF concept's custom_frontmatter.
      # Occupiability and status are independent: Appwork::Chorus::Workable supplies the
      # `has_one :workspace, as: :workable` inverse; `okf_frontmatter :status`
      # (an OKF facility) supplies the status accessor over the concept.
      has_one_okf :concept
      okf_frontmatter :status
      include Appwork::Chorus::Workable

      has_many :tickets, dependent: :destroy

      validates :name, presence: true
    end
  end
end
