# frozen_string_literal: true

require "listen"

module Appwork
  module Okf
    # Watches bundle roots and triggers Appwork::Okf::Sync on change.
    #
    # A TRIGGER, not a mechanism. All reconciliation logic lives in Sync; this class
    # only answers "which bundle owns this path, and which paths changed". If it ever
    # grows a decision, that decision belongs in Sync. Keeping this class dumb is what
    # lets us swap `listen` for polling / a queue / a webhook on a multi-host setup
    # without touching anything downstream — and it's why this class is barely tested
    # (there is nothing here to test but the routing).
    #
    # NOTE: `listen` runs a background thread in the calling process. Spawn this in a
    # DEDICATED process (Procfile.dev entry / systemd unit) — never a Rails
    # initializer, which would boot a listener inside console, rspec, db:migrate, and
    # every Puma worker.
    class Listener
      include Partitia::Support::Logging

      def self.run(bundles: Appwork::Okf::Bundle.all)
        new(bundles: bundles).run
      end

      def initialize(bundles:)
        # Key by realpath: `listen` emits canonical (symlink-resolved) paths, so a
        # bundle rooted under a symlink (e.g. macOS /tmp -> /private/tmp) would never
        # prefix-match its own events unless the roots are canonicalized the same way.
        #
        # Array() so a single record (Bundle.first) works as well as a collection
        # (Bundle.all): it leaves an Array untouched, wraps one record as [record],
        # and flattens a relation via to_ary — and Array(nil)/Array([]) stay empty
        # so the guard below still fires.
        @bundles = Array(bundles).index_by { |b| canonical(b.pathname) }
        raise ArgumentError, "no bundles to watch" if @bundles.empty?
      end

      def run
        logger.info { "#{self.class} watching #{@bundles.keys.join(', ')}" }

        listener = Listen.to(*@bundles.keys,
                             only: Config.listen_only,
                             latency: Config.listen_latency) do |modified, added, removed|
          route(modified + added + removed)
        end

        listener.start
        sleep
      rescue Interrupt
        logger.info { "#{self.class} stopping" }
        listener&.stop
      end

      private

      # Group absolute paths by owning bundle, then hand each bundle its own
      # bundle-relative paths in ONE Sync call. All three event arrays are merged
      # into one list on purpose: an editor that saves via temp-file+rename (Neovim's
      # default) fires removed+added rather than modified, and Sync's set-based
      # reconciliation figures out the end state from the hash — so the listener must
      # never interpret event TYPES.
      def route(paths)
        paths.filter_map { |p| resolve(p) }
             .group_by(&:first)
             .each do |bundle, pairs|
               Appwork::Okf::Sync.call(bundle: bundle, paths: pairs.map(&:last))
             end
      rescue => e
        # A listener that dies on one bad event is worse than one that logs and
        # keeps watching — an exception inside a `listen` callback can kill the
        # thread silently.
        logger.error { "#{self.class} sync failed: #{e.class}: #{e.message}" }
      end

      # Longest-matching-prefix wins, so a bundle rooted INSIDE another bundle
      # correctly claims its own files rather than both firing. The trailing slash
      # keeps /a/bundle from claiming /a/bundle-other/x.md.
      def resolve(abs_path)
        root = @bundles.keys.select { |r| abs_path.start_with?("#{r}/") }.max_by(&:length)
        return nil unless root

        [ @bundles[root], Pathname.new(abs_path).relative_path_from(Pathname.new(root)).to_s ]
      end

      # Resolve symlinks so roots match `listen`'s canonical event paths. Guarded:
      # a path that does not exist (e.g. a test double's fake root) is used as-is.
      def canonical(pathname)
        pathname.exist? ? pathname.realpath.to_s : pathname.to_s
      end
    end
  end
end
