module Appwork
  module Okf
    class Concept < ApplicationRecord
      include FsNode
      include FsConcept

      self.inheritance_column = nil   # `type` is an OKF field, not Rails STI

      FRONTMATTER_COLUMNS = %w[type title description resource tags timestamp].freeze

      belongs_to :bundle, class_name: "Appwork::Okf::Bundle", inverse_of: :concepts

      serialize :custom_frontmatter, coder: YAML, type: Hash

      validates :content_hash, presence: true

      def pathname = bundle.pathname.join(path)

      def ident
        return unless super

        self.content_hash = Digest::MD5.hexdigest(raw_content)
        apply_frontmatter
      end

      # True when the file on disk no longer matches what the DB last recorded.
      # Derived, not stored: under the :quarantine policy Sync declines to update a
      # diverged owned concept, leaving content_hash stale — which is exactly what
      # keeps the concept detectably diverged for a downstream review queue.
      def diverged?
        return false unless pathname.exist?

        content_hash != Digest::MD5.hexdigest(pathname.read)
      end

      private

      def apply_frontmatter
        fm = frontmatter
        known   = fm.slice(*FRONTMATTER_COLUMNS).reject { |col, _| changed.include?(col) }
        unknown = fm.except(*FRONTMATTER_COLUMNS)

        known.each { |col, val| public_send(:"#{col}=", val) }
        self.custom_frontmatter = unknown.presence || {} unless custom_frontmatter_changed?
      end
    end
  end
end
