class Strategy < ApplicationRecord
  include Okf::Consumer

  belongs_to :organization
  has_many :goals, dependent: :destroy

  owns_one_okf :concept

  # Delegate frontmatter access to the owned concept — BY HAND (no DSL yet).
  # Standard fields via delegate; a custom field written long-form so we can
  # feel what a future `okf_frontmatter :priority` macro would generate.
  delegate :title, :description, to: :concept, allow_nil: true

  def priority
    concept&.custom_frontmatter&.dig("priority")
  end

  def priority=(value)
    concept.custom_frontmatter = (concept.custom_frontmatter || {}).merge("priority" => value)
  end
end
