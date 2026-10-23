module Appwork
  module Gtd
    # A GTD project groups actions and owns its own content (title/notes) on disk
    # via an OKF concept — a lighter consumer than Action (no placement/assertion
    # hats; the project board reads its title, it is not a placement subject itself).
    class Project < ApplicationRecord
      self.table_name = "appwork_gtd_projects"
      include Appwork::Okf::Consumer

      has_many :actions, class_name: "Appwork::Gtd::Action", dependent: :nullify

      has_one_okf :concept

      delegate :title, to: :concept, allow_nil: true

      def body = concept&.content
    end
  end
end
