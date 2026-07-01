module CnfsOkf
  module FsConcept
    extend ActiveSupport::Concern

    included do
      around_save :persist_to_disk, if: :frontmatter_changed?
    end

    FRONTMATTER_PATTERN = /\A---\r?\n(.*?)\n---\r?\n?/m

    def raw_content = (@raw_content ||= pathname.read)

    def content
      _fm, body = split_frontmatter(raw_content)
      body
    end

    def frontmatter
      fm, _body = split_frontmatter(raw_content)
      fm
    end

    private

    # Writes updated frontmatter to disk before the DB record is saved.
    # On write failure, logs and aborts the save so the DB stays consistent
    # with the file. If the write succeeds but the DB save subsequently fails,
    # the file is ahead of the DB — this self-heals on the next sync.
    def persist_to_disk
      @raw_content = nil
      _fm, body = split_frontmatter(pathname.read)
      new_content = build_file_content(body)

      begin
        pathname.write(new_content)
      rescue => e
        Rails.logger.error("CnfsOkf::Concept#persist_to_disk failed writing '#{pathname}': #{e.message}")
        throw(:abort)
      end

      self.content_hash = Digest::MD5.hexdigest(new_content)
      @raw_content = new_content
      yield
    end

    # True when any frontmatter-mapped attribute has changed on a persisted record.
    # Skipped on new records — frontmatter is read FROM the file on create, not written back.
    def frontmatter_changed?
      return false if new_record?

      (changed & self.class::FRONTMATTER_COLUMNS).any? || custom_frontmatter_changed?
    end

    # Builds a hash of all non-nil frontmatter columns merged with custom_frontmatter.
    def build_frontmatter_hash
      fm = self.class::FRONTMATTER_COLUMNS.each_with_object({}) do |col, hash|
        val = public_send(col)
        hash[col] = val unless val.nil?
      end
      custom_frontmatter.present? ? fm.merge(custom_frontmatter) : fm
    end

    # Reconstructs the full file content from current attribute values and the
    # existing body. Omits the frontmatter block entirely if all fields are blank.
    def build_file_content(body)
      fm = build_frontmatter_hash
      return body if fm.empty?

      "---\n#{YAML.dump(fm).sub(/\A---\n/, "")}---\n#{body}"
    end

    def split_frontmatter(raw)
      if (m = raw.match(FRONTMATTER_PATTERN))
        parsed = YAML.safe_load(m[1], permitted_classes: [ Date, Time, DateTime ]) || {}
        [ parsed, raw[m[0].length..] ]
      else
        [ {}, raw ]
      end
    end
  end
end
