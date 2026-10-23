module Appwork
  module Chorus
    # A managed origin: remote (or local) content materialized to a path on disk.
    # Primarily used to clone code repos a Workspace acts on, but also backs any
    # directory whose bytes come from — and refresh from — an external origin
    # (e.g. an OKF bundle later declared with `Appwork::Okf::Bundle.create(owner: src)`).
    #
    # Source operates on the transport/provenance axis: fetch bytes, track a ref,
    # detect drift. It knows nothing about OKF, Concepts, or indexing — declaring a
    # Source's path as OKF content is a separate, downstream step.
    #
    # STI. Behaviour (how you clone/pull/verify) varies by kind and lives in the
    # subclasses. Data varies too: shared/queryable fields (`resource`, `path`,
    # `ref`, `synced_at`, `digest`) are real columns; per-kind config lives in the
    # serialized `settings` bag so the table carries no wasted per-kind columns.
    #
    # Account-scoped by tenancy (one physical DB per Account). The Workspace
    # lease/claim relationship (one holder at a time, wait-and-release) is deferred
    # to PHASE-B and deliberately absent here.
    class Source < ApplicationRecord
      # A Workspace owns the sources checked out into it (plan 011 §6); optional so a
      # source may exist before it is attached to a place.
      belongs_to :owner, polymorphic: true, optional: true

      serialize :settings, coder: YAML, type: Hash

      validates :type, presence: true
      validates :resource, presence: true

      after_initialize { self.settings ||= {} }

      # Declares a reader/writer backed by a key in the serialized `settings` bag,
      # so subclasses expose their kind-specific config as first-class accessors
      # without adding columns. e.g. `setting :branch` -> #branch / #branch=.
      def self.setting(*names)
        names.each do |name|
          define_method(name) { settings[name.to_s] }
          define_method(:"#{name}=") { |value| self.settings = settings.merge(name.to_s => value) }
        end
      end

      # --- Transport interface: implemented per kind by subclasses ---------------

      # Materialize the origin to `path` for the first time.
      def fetch = raise(NotImplementedError, "#{self.class} must implement #fetch")

      # Bring an already-materialized path up to date with the origin.
      def refresh = raise(NotImplementedError, "#{self.class} must implement #refresh")

      # The origin's current upstream ref (commit SHA / etag / mtime), independent
      # of what we last synced. Used to detect whether a refresh is needed.
      def current_ref = raise(NotImplementedError, "#{self.class} must implement #current_ref")

      # True when the upstream ref differs from the last-synced ref.
      def stale? = ref != current_ref

      def pathname = Pathname.new(path)

      private

      # Emit all Source instrumentation under the `partitia_appwork.source.*` prefix,
      # regardless of STI subclass. The default Instrumentable#instrument derives
      # the subject from the demodulized class name, so a three-level subclass
      # like Appwork::Chorus::Source::Git would emit "partitia_appwork.git.<verb>". Pinning the
      # subject to "Appwork::Chorus::Source" (matching the logging tag) gives every kind a
      # stable "partitia_appwork.source.<verb>" event name.
      def instrument(verb, **payload, &block)
        name = Partitia::Support::Instrumentable.event_name("Appwork::Chorus::Source", verb)
        ActiveSupport::Notifications.instrument(name, **payload, &block)
      end
    end
  end
end
