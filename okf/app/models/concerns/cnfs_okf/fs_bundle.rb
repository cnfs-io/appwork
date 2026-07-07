module CnfsOkf
  module FsBundle
    extend ActiveSupport::Concern

    included do
      after_update :sync_concepts, if: :saved_change_to_path?
    end

    def mv(new_path)
      dest = Pathname.new(new_path).expand_path

      if dest.exist?
        logger.error { "CnfsOkf::Bundle#mv failed: destination '#{dest}' already exists" }
        return false
      end

      unless dest.dirname.exist?
        logger.error { "CnfsOkf::Bundle#mv failed: parent directory '#{dest.dirname}' does not exist" }
        return false
      end

      begin
        pathname.rename(dest)
        update!(path: dest.to_s)
      rescue => e
        logger.error { "CnfsOkf::Bundle#mv failed moving '#{pathname}' to '#{dest}': #{e.message}" }
        false
      end
    end

    # Reconciles concept records with the markdown files currently on disk.
    # Triggered after_update when the bundle's path changes (e.g. via #mv).
    #
    # Three outcomes per concept/file:
    #   - file still exists at same relative path → kept as-is
    #   - file no longer exists → concept destroyed (skipped with a warning if it has an owner)
    #   - new file on disk with no concept record → concept created
    #
    # Short-circuits entirely if ino_match? determines the bundle root simply
    # moved on the same filesystem (all inodes match), meaning no concepts need
    # to change.
    def sync_concepts
      # Standardized notification via CnfsSupport::Instrumentable, emitted as
      # "cnfs_okf.bundle.sync". The block's duration becomes the span duration;
      # the payload keys become span attributes. Enriched mid-block with the
      # reconciliation outcome counts.
      instrument(:sync, bundle_id: id, path: path) do |payload|
        current_paths     = concept_paths.map(&:to_s)  # relative paths of files on disk now
        existing_concepts = concepts.to_a               # concept records currently in the DB

        if ino_match?(existing_concepts, current_paths)
          payload[:ino_match] = true
          next
        end

        existing_paths = existing_concepts.map(&:path)
        destroyed_count = 0
        skipped_count   = 0

        # Destroy concepts whose files no longer exist at the new location.
        existing_concepts.each do |concept|
          next if current_paths.include?(concept.path)

          if concept.owner.present?
            # Deleting an owned concept could orphan the owning record — skip and warn.
            skipped_count += 1
            logger.warn do
              "CnfsOkf::Bundle#sync_concepts: skipping stale concept id=#{concept.id} " \
              "path=#{concept.path.inspect} — owner #{concept.owner_type}##{concept.owner_id} is set"
            end
          else
            concept.destroy
            destroyed_count += 1
          end
        end

        # Create concepts for files that appeared in the new location.
        created = (current_paths - existing_paths).map { |p| concepts.find_or_create_by(path: p) }

        payload[:created_count]   = created.size
        payload[:destroyed_count] = destroyed_count
        payload[:skipped_count]   = skipped_count
        logger.info { "#{self.class}#sync_concepts created=#{created.size} destroyed=#{destroyed_count} skipped=#{skipped_count}" }
        created
      end
    end

    private

    # Returns true if every existing concept's stored inode matches the inode
    # of the file at its relative path under the (possibly new) bundle pathname.
    #
    # A full inode match means the bundle directory was renamed on the same
    # filesystem — the files are byte-for-byte identical objects, just at a new
    # root. In that case sync_concepts can skip all create/destroy work entirely.
    #
    # A count mismatch (or empty set) short-circuits early since the sets cannot
    # all match if their sizes differ.
    def ino_match?(existing_concepts, current_paths)
      return false if existing_concepts.empty? || existing_concepts.length != current_paths.length

      existing_concepts.all? do |concept|
        concept.pathname.exist? && concept.pathname.stat.ino == concept.ino
      end
    end
  end
end
