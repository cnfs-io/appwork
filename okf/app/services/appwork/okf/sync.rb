# frozen_string_literal: true

module CnfsOkf
  # Reconciles a Bundle's DB projection against its current on-disk content.
  #
  # THE single entry point for reconciliation. Idempotent — calling it twice in a
  # row does nothing the second time, which is what makes a lost filesystem event
  # a latency cost rather than a correctness bug, and what makes a full sync at
  # boot cheap enough to be unconditional.
  #
  # Knows nothing about `listen`. A listener is one possible trigger; a rake task,
  # a console, and a boot hook are others.
  #
  # The owned-concept policy (CnfsOkf::Config.owned_concept_policy) governs what
  # happens to a concept WITH an owner that changed on disk. Unowned concepts are
  # always reconciled disk-wins. See doc/plans/PLAN-sync-and-listener.md.
  class Sync
    include CnfsSupport::Logging
    include CnfsSupport::Instrumentable

    Result = Struct.new(:created, :updated, :destroyed, :skipped, :quarantined,
                        :unchanged, keyword_init: true) do
      def self.zero = new(created: 0, updated: 0, destroyed: 0, skipped: 0,
                          quarantined: 0, unchanged: 0)

      def changed? = created.positive? || updated.positive? || destroyed.positive?

      def to_s
        "created=#{created} updated=#{updated} destroyed=#{destroyed} " \
        "unchanged=#{unchanged} skipped=#{skipped} quarantined=#{quarantined}"
      end
    end

    def self.call(bundle:, paths: nil) = new(bundle:, paths:).call

    def initialize(bundle:, paths: nil)
      @bundle = bundle
      @paths  = paths&.map(&:to_s) # bundle-relative; nil => whole bundle
      @result = Result.zero
    end

    def call
      instrument(:run, bundle_id: @bundle.id, path: @bundle.path,
                       policy: Config.owned_concept_policy) do |payload|
        @disk      = disk_paths
        @db_by_path = db_concepts.index_by(&:path)

        reconcile_deletions
        reconcile_disk_files

        payload.merge!(@result.to_h)
        logger.info { "#{self.class} bundle=#{@bundle.id} #{@result}" }
        @result
      end
    end

    private

    # Relative path strings currently on disk, restricted to @paths when scoped.
    def disk_paths
      current = @bundle.concept_paths.map(&:to_s)
      @paths ? current & @paths : current
    end

    # Concept records to consider, restricted to @paths when scoped. A scoped run
    # must NOT see concepts outside its paths — otherwise it would read them as
    # "in DB, not on disk" and destroy them. Incremental, not catastrophic.
    #
    # Loads FRESH instances (reload): a Bundle handed in may carry a cached
    # concepts association whose members memoized @raw_content at create time —
    # stale bytes would make every changed file read as unchanged. reload keeps
    # inverse_of, so concept.bundle stays wired (no N+1 in #pathname).
    def db_concepts
      concepts = @bundle.concepts.reload.to_a
      @paths ? concepts.select { |c| @paths.include?(c.path) } : concepts
    end

    # In DB, not on disk → destroy, subject to policy.
    def reconcile_deletions
      disk = @disk.to_set
      @db_by_path.each_value do |concept|
        next if disk.include?(concept.path)

        if policy_allows_destroy?(concept)
          concept.destroy
          @result.destroyed += 1
        else
          @result.skipped += 1
          logger.warn do
            "#{self.class}: skipping stale owned concept id=#{concept.id} " \
            "path=#{concept.path.inspect} — owner #{concept.owner_type}##{concept.owner_id} is set"
          end
        end
      end
    end

    # On disk → create if new, else compare and maybe update.
    def reconcile_disk_files
      @disk.each do |rel|
        if (concept = @db_by_path[rel])
          reconcile_existing(concept)
        else
          @bundle.concepts.create!(path: rel)
          @result.created += 1
        end
      end
    end

    # Reads the file ONCE via raw_content (memoized on the instance) so both the
    # hash comparison and a subsequent apply_from_disk reuse the same bytes.
    def reconcile_existing(concept)
      disk_hash = Digest::MD5.hexdigest(concept.raw_content)

      if concept.content_hash == disk_hash
        @result.unchanged += 1
      elsif policy_allows_update?(concept)
        apply_from_disk(concept)
        @result.updated += 1
      else
        @result.quarantined += 1
        logger.info do
          "#{self.class}: quarantined diverged owned concept id=#{concept.id} " \
          "path=#{concept.path.inspect} — DB left untouched, concept remains diverged?"
        end
      end
    end

    # Re-runs the disk→DB path `ident` already performs (stat -> ino,
    # hash -> content_hash, parse -> frontmatter), then saves — with disk write
    # suppressed so the assignment does not bounce straight back out to the file
    # and re-trigger the listener.
    def apply_from_disk(concept)
      concept.without_persist do
        concept.ident
        concept.save!
      end
    end

    def owned?(concept) = concept.owner_id.present?

    # Deletion of an owned concept could orphan the owning record. Only :disk_wins
    # destroys it; :protect and :quarantine skip and warn (today's behaviour).
    def policy_allows_destroy?(concept)
      return true unless owned?(concept)

      Config.disk_wins?
    end

    # Content change to an owned concept: :disk_wins / :protect apply it,
    # :quarantine declines (leaving content_hash stale, so it stays diverged?).
    def policy_allows_update?(concept)
      return true unless owned?(concept)

      !Config.quarantine?
    end
  end
end
