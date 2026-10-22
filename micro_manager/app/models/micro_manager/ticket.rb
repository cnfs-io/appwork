module MicroManager
  class Ticket < ApplicationRecord
    belongs_to :project

    # The assignee is a Chorus agent. `class_name` is a STRING (no Ruby
    # dependency on Chorus); the column carries a real DB FK to chorus_agents
    # because both gems' tables are colocated in one database. Assignment runs
    # org → Chorus, the allowed direction.
    belongs_to :agent, class_name: "Chorus::Agent", optional: true

    # A Ticket is a Chorus workable (occupiable by a Chorus::Workspace) that
    # carries an opaque status in its OKF concept's custom_frontmatter.
    # Occupiability and status are independent: Chorus::Workable supplies the
    # `has_one :workspace, as: :workable` inverse; `okf_frontmatter :status`
    # supplies the status accessor over the concept.
    has_one_okf :concept
    okf_frontmatter :status
    include Chorus::Workable

    validates :title, presence: true
  end
end
