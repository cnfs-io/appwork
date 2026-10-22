# frozen_string_literal: true

require "cnfs_support"

module Chorus
  # Secrets Chorus itself names and resolves (anyway_config). Distinct from any
  # future framework config: the YAML/credentials name is the honest
  # `chorus_credentials`, while the ENV prefix stays the ergonomic `CHORUS_` so
  # the op-populated variable is CHORUS_GITHUB_TOKEN.
  #
  # Every attribute here is a SECRET: resolves from
  # credentials.chorus_credentials.* or CHORUS_*, never a source literal, never
  # logged, never in an instrumentation payload.
  class Credentials < CnfsSupport::Config
    config_name :chorus_credentials   # -> config/chorus_credentials.yml, credentials.chorus_credentials
    env_prefix  :chorus               # -> ENV["CHORUS_GITHUB_TOKEN"]

    attr_config :github_token
  end
end
