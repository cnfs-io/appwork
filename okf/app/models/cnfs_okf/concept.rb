module CnfsOkf
  class Concept < ApplicationRecord
    self.inheritance_column = nil   # `type` is an OKF field, not Rails STI

    FRONTMATTER_COLUMNS = %w[type title description resource tags timestamp].freeze

    belongs_to :bundle, class_name: "CnfsOkf::Bundle", inverse_of: :concepts
    belongs_to :owner, polymorphic: true, optional: true

    serialize :custom_frontmatter, coder: YAML, type: Hash

    before_validation :stat_it, unless: ->(record) { record.path.nil? }
    validates :path, presence: true
    validate :path_must_exist, unless: ->(record) { record.path.nil? }

    def pathname
      bundle.pathname.join(path)
    end

    def stat_it
      return unless (file = pathname) && file.exist?

      file_stat = file.stat
      self.ino = file_stat.ino
      self.content_hash = Digest::MD5.hexdigest(raw_content)
      apply_frontmatter
    end

    def path_must_exist
      errors.add(:path, "'#{pathname}' does not exist") unless pathname.exist?
    end

    # Raw bytes of the file.
    def raw_content
      pathname.exist? ? pathname.read : ""
    end

    # Body text with frontmatter stripped.
    def content
      _fm, body = split_frontmatter(raw_content)
      body
    end

    # Parsed frontmatter hash (all keys).
    def frontmatter
      fm, _body = split_frontmatter(raw_content)
      fm
    end

    private

    FRONTMATTER_PATTERN = /\A---\r?\n(.*?)\n---\r?\n?/m

    def split_frontmatter(raw)
      if (m = raw.match(FRONTMATTER_PATTERN))
        parsed = YAML.safe_load(m[1], permitted_classes: [ Date, Time, DateTime ]) || {}
        [ parsed, raw[m[0].length..] ]
      else
        [ {}, raw ]
      end
    end

    def apply_frontmatter
      fm = frontmatter
      known   = fm.slice(*FRONTMATTER_COLUMNS)
      unknown = fm.except(*FRONTMATTER_COLUMNS)

      known.each { |col, val| public_send(:"#{col}=", val) }
      self.custom_frontmatter = unknown.presence || {}
    end
  end
end
