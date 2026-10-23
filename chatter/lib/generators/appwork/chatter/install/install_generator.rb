require "rails/generators"

module Appwork
  module Chatter
    module Generators
      # `bin/rails g appwork:chatter:install` — the deterministic wiring a host app runs once to
      # adopt chatter. For this milestone it does the one mechanical thing a host
      # cannot skip: mount the engine into the host's routes. Mirrors the partitia-ui
      # install-generator idiom (Rails' own `route` helper + `say_status`).
      #
      # Deliberately standalone: chatter does NOT depend on partitia-ui, so this writes
      # no chrome/layout/Tailwind wiring. If chatter later composes partitia-ui, that is
      # a separate decision and a separate generator step — not smuggled in here.
      #
      # The host must still satisfy chatter's two config seams itself (they are not
      # mechanical enough to generate): set `Appwork::Chatter.parent_controller` to a base
      # controller providing `current_participant`, and supply
      # `Appwork::Chatter.participant_candidates`. See the engine README.
      class InstallGenerator < Rails::Generators::Base
        MOUNT_PATH = "/chatter".freeze

        desc "Mount Appwork::Chatter::Engine into the host application's routes."

        def mount_engine
          # Rails' `route` helper is idempotent for an identical line — re-running
          # will not duplicate the mount.
          route %(mount Appwork::Chatter::Engine => "#{MOUNT_PATH}")
          say_status :mount, %(Appwork::Chatter::Engine => "#{MOUNT_PATH}"), :green
        end
      end
    end
  end
end
