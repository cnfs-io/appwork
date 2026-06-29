module Okf
  class Concept < ApplicationRecord
    self.inheritance_column = nil   # `type` is an OKF field, not Rails STI

    belongs_to :bundle, class_name: "Okf::Bundle", inverse_of: :concepts
    belongs_to :owner, polymorphic: true, optional: true

    serialize :custom_frontmatter, coder: YAML, type: Hash

    # Absolute path of this concept's file: its bundle's pathname + relative path.
    def pathname
      bundle.pathname.join(path)
    end
  end
end
