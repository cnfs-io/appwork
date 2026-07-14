# frozen_string_literal: true

require "cnfs_support"

module CnfsOkf
  # Config surface for the OKF engine. A CnfsSupport::Config subclass
  # (anyway_config), so every value resolves, in ascending priority:
  #   1. config/cnfs_okf.yml in the consumer app
  #   2. Rails credentials under the `cnfs_okf` key
  #   3. ENV: CNFS_OKF_OWNED_CONCEPT_POLICY, CNFS_OKF_LISTEN_LATENCY, ...
  #
  # A consumer app overrides in an initializer:
  #
  #   # config/initializers/cnfs_okf.rb
  #   CnfsOkf::Config.owned_concept_policy = :quarantine
  #
  # See doc/plans/PLAN-sync-and-listener.md for the owned-concept policy design.
  class Config < CnfsSupport::Config
    config_name :cnfs_okf

    OWNED_CONCEPT_POLICIES = %i[disk_wins protect quarantine].freeze

    attr_config(
      # Governs CnfsOkf::Sync's treatment of OWNED concepts that changed on disk.
      # Unowned concepts are always reconciled disk-wins.
      owned_concept_policy: :protect,

      # Seconds `listen` coalesces filesystem events before firing the callback.
      listen_latency: 0.5,

      # Regexp, matched against absolute paths, of files the listener watches.
      # Mirrors Bundle::CONCEPT_SEARCH_PATTERN as a regexp for listen's `only:`.
      # Config/initializer-only — a Regexp cannot come from ENV meaningfully.
      listen_only: /\.md\z/
    )

    # ENV always arrives as a String; an initializer naturally assigns a Symbol.
    # Coercing to String and symbolizing on read normalizes both paths to a Symbol.
    coerce_types owned_concept_policy: :string, listen_latency: :float

    def owned_concept_policy
      super.to_sym
    end

    def quarantine? = owned_concept_policy == :quarantine
    def protect?    = owned_concept_policy == :protect
    def disk_wins?  = owned_concept_policy == :disk_wins

    on_load do
      unless OWNED_CONCEPT_POLICIES.include?(owned_concept_policy)
        raise_validation_error(
          "owned_concept_policy must be one of #{OWNED_CONCEPT_POLICIES.join(', ')} " \
          "(got #{owned_concept_policy.inspect})"
        )
      end
    end
  end
end
