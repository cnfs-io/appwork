# frozen_string_literal: true

require "cnfs_support"

module Chorus
  # Non-secret framework configuration (anyway_config), so every value resolves
  # from config/chorus.yml -> credentials.chorus -> ENV["CHORUS_*"] with one
  # precedence, the family convention. Distinct from Chorus::Credentials, which
  # holds SECRETS (the GitHub token) under the honest `chorus_credentials` name;
  # this class holds non-secret DATA the deploy environment sets.
  #
  # A tenant's CURATION POSTURE is configuration, not data — it does not belong on
  # any model. It lives here as two knobs:
  #
  #   * curation_enabled       — whether chorus.org's curation is in force.
  #   * reputation_threshold   — the minimum reputation required when curation is on.
  #
  # # 004 default decision: curation_enabled defaults TRUE (curated by default),
  # reputation_threshold defaults 50 (a modest non-zero bar — reject the bottom
  # half of graded skills, admit nothing chorus.org flagged as trash). These are
  # the plumbing defaults; see progress.md.
  #
  # # 004 deferred: NO policy consumes these yet. How curation_enabled +
  # reputation_threshold actually gate/rank the catalog (and whether nil/unreviewed
  # passes when curation is on) is policy, deferred to a later plan. This class only
  # establishes where the knobs live.
  class Config < CnfsSupport::Config
    config_name :chorus   # -> config/chorus.yml, credentials.chorus, ENV["CHORUS_*"]

    attr_config curation_enabled: true, reputation_threshold: 50

    # anyway_config coerces string ENV/YAML values; keep these honestly typed.
    coerce_types curation_enabled: :boolean, reputation_threshold: :integer
  end
end
