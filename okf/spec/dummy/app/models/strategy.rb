class Strategy < ApplicationRecord
  belongs_to :account
  has_many :goals, dependent: :destroy

  has_one_okf :concept

  # Standard Concept columns via plain delegate; a custom-frontmatter key via
  # the okf_frontmatter macro (generates the priority/priority= accessor pair
  # over concept.custom_frontmatter).
  delegate :title, :description, to: :concept, allow_nil: true

  okf_frontmatter :priority
end
