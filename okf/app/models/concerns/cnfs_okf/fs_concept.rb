module CnfsOkf
  module FsConcept
    extend ActiveSupport::Concern

    included do
      around_save :persist_to_disk, if: :file_changed?
    end

    FRONTMATTER_PATTERN = /\A---\r?\n(.*?)\n---\r?\n?/m

    def raw_content = (@raw_content ||= pathname.read)

    # Runs the block with disk-write suppressed. Used by CnfsOkf::Sync, which is
    # assigning attributes that came FROM disk — writing them back would be a
    # gratuitous no-op write that re-stamps content_hash and re-triggers the
    # filesystem listener. Nothing else should use this.
    def without_persist
      @suppress_persist = true
      yield
    ensure
      @suppress_persist = false
    end

    # Stages a new markdown BODY (the file minus its frontmatter block). Not an AR
    # attribute — `content` is derived from the file on every read, and there is no
    # `content` column by design (content_hash already carries change detection).
    #
    # Staging here + the `content_changed?` branch in `file_changed?` is what routes
    # a body edit through the SAME `persist_to_disk` path a frontmatter edit takes:
    # one write, one hash stamp, one instrumentation span, one abort-on-failure
    # contract. A consumer must never write the file itself.
    def content=(value)
      @pending_content = value.to_s
    end

    def content
      return @pending_content if defined?(@pending_content) && @pending_content

      _fm, body = split_frontmatter(raw_content)
      body
    end

    # True when a staged body differs from the body currently on disk. Reads disk
    # (not raw_content's memo) so a stale memo can't mask a real change.
    def content_changed?
      return false unless defined?(@pending_content) && @pending_content

      _fm, body = split_frontmatter(raw_content)
      @pending_content != body
    end

    def frontmatter
      fm, _body = split_frontmatter(raw_content)
      fm
    end

    private

    # Writes the file (frontmatter block + body) to disk before the DB record is
    # saved. On write failure, logs and halts the save so the DB stays consistent
    # with the file. If the write succeeds but the DB save subsequently fails,
    # the file is ahead of the DB — this self-heals on the next sync.
    def persist_to_disk
      @raw_content = nil
      _fm, disk_body = split_frontmatter(pathname.read)
      # Two possible body sources: a staged edit (@pending_content) wins over the
      # body currently on disk. A frontmatter-only edit stages nothing, so the disk
      # body is preserved verbatim.
      body = (defined?(@pending_content) && @pending_content) || disk_body
      body = "#{body}\n" unless body.empty? || body.end_with?("\n")
      new_content = build_file_content(body)

      # Standardized notification via CnfsSupport::Instrumentable, emitted as
      # "cnfs_okf.concept.persist". Scoped to the disk write only — the DB save
      # continuation (`yield`) stays outside the span, preserving the
      # around_save contract. The exception propagates through instrument (so the
      # notification records it) and is caught below.
      begin
        instrument(:persist, concept_id: id, path: path, bytes: new_content.bytesize) do
          pathname.write(new_content)
        end
      rescue => e
        logger.error { "CnfsOkf::Concept#persist_to_disk failed writing '#{pathname}': #{e.message}" }
        # Halt the save WITHOUT writing the DB, keeping it consistent with the
        # unwritten file. An around_save can't `throw(:abort)` — Rails only
        # catches that from before-callbacks — so we halt the idiomatic way: skip
        # the `yield`. `save` then returns falsy, `save!` raises RecordNotSaved,
        # and @pending_content survives (we return before its reset) for a retry
        # or form re-render.
        return false
      end

      self.content_hash = Digest::MD5.hexdigest(new_content)
      @raw_content = new_content
      # Clear the stage only on a successful write, so a redundant re-save is a
      # no-op. The write-failure `return` above never reaches here, leaving
      # @pending_content set for a retry or a form re-render.
      @pending_content = nil
      yield
    end

    # True when EITHER the frontmatter or the body has changed on a persisted
    # record. Skipped on new records — content is read FROM the file on create,
    # not written back — and while a disk-sourced assignment is suppressed.
    def file_changed?
      return false if new_record?
      return false if @suppress_persist

      frontmatter_changed? || content_changed?
    end

    # True when any frontmatter-mapped attribute has changed. Guarded by
    # file_changed?, its only caller — which owns the new_record?/suppress checks.
    def frontmatter_changed?
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
