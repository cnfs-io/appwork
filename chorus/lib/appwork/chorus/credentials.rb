# frozen_string_literal: true

require "partitia/support"

module Appwork
  module Chorus
    # Secrets Chorus itself names and resolves (anyway_config). Distinct from any
    # future framework config: the YAML/credentials name is the honest
    # `appwork_chorus_credentials`, while the ENV prefix stays the ergonomic `APPWORK_CHORUS_` so
    # the op-populated variable is APPWORK_CHORUS_GITHUB_TOKEN.
    #
    # Every attribute here is a SECRET: resolves from
    # credentials.chorus_credentials.* or APPWORK_CHORUS_*, never a source literal, never
    # logged, never in an instrumentation payload.
    class Credentials < Partitia::Support::Config
      config_name :appwork_chorus_credentials   # -> config/chorus_credentials.yml, credentials.chorus_credentials
      env_prefix  :appwork_chorus               # -> ENV["APPWORK_CHORUS_GITHUB_TOKEN"]

      attr_config :github_token
    end
  end
end
