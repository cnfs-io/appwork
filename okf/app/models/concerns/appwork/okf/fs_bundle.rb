module Appwork
  module Okf
    module FsBundle
      extend ActiveSupport::Concern

      included do
        after_update :sync_concepts, if: :saved_change_to_path?
      end

      def mv(new_path)
        dest = Pathname.new(new_path).expand_path

        if dest.exist?
          logger.error { "Appwork::Okf::Bundle#mv failed: destination '#{dest}' already exists" }
          return false
        end

        unless dest.dirname.exist?
          logger.error { "Appwork::Okf::Bundle#mv failed: parent directory '#{dest.dirname}' does not exist" }
          return false
        end

        begin
          pathname.rename(dest)
          update!(path: dest.to_s)
        rescue => e
          logger.error { "Appwork::Okf::Bundle#mv failed moving '#{pathname}' to '#{dest}': #{e.message}" }
          false
        end
      end

      # Reconcile this bundle's concepts against disk. Delegates the algorithm to
      # Appwork::Okf::Sync — thin model, reconciliation lives in the service. Triggered
      # after_update when the bundle's path changes (e.g. via #mv), and callable
      # directly.
      #
      # Short-circuits entirely if ino_match? determines the bundle root simply
      # moved on the same filesystem (all inodes match), meaning no concept work is
      # needed.
      def sync_concepts(paths: nil)
        return if ino_match? # bundle merely moved on the same fs; nothing to do

        Appwork::Okf::Sync.call(bundle: self, paths:)
      end

      private

      # A full inode match means the bundle directory was renamed on the same
      # filesystem — the files are byte-for-byte identical objects, just at a new
      # root — so no concept work is needed. A guard about THIS bundle's identity,
      # not a reconciliation algorithm, which is why it stays on the model.
      #
      # A count mismatch (or empty set) short-circuits early since the sets cannot
      # all match if their sizes differ.
      def ino_match?
        existing = concepts.to_a
        current  = concept_paths.map(&:to_s)
        return false if existing.empty? || existing.length != current.length

        existing.all? { |c| c.pathname.exist? && c.pathname.stat.ino == c.ino }
      end
    end
  end
end
