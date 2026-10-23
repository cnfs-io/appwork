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
        DATABASE_YML = "config/database.yml".freeze
        REGISTRY = "Partitia::Support.migrations_paths".freeze

        desc "Mount Appwork::Chatter::Engine into the host application's routes, check " \
             "database.yml reads the partitia-support registry, and print what is left."

        def mount_engine
          # Rails' `route` helper is idempotent for an identical line — re-running
          # will not duplicate the mount.
          route %(mount Appwork::Chatter::Engine => "#{MOUNT_PATH}")
          say_status :mount, %(Appwork::Chatter::Engine => "#{MOUNT_PATH}"), :green
        end

        # Chatter's migrations reach the app through partitia-support's registry, never by
        # copying (partitia ARCHITECTURE §5).
        def check_migrations_paths
          path = File.join(destination_root, DATABASE_YML)
          @registry_wired = File.exist?(path) && File.read(path).include?(REGISTRY)
          if @registry_wired
            say_status :ok, "#{DATABASE_YML} reads #{REGISTRY}", :blue
          else
            say_status :missing, "#{DATABASE_YML} does not read #{REGISTRY}", :yellow
          end
        end

        def print_post_install
          say ""
          say "appwork-chatter installed at #{MOUNT_PATH}. Still to do:", :green
          unless @registry_wired
            say "  - bin/rails generate partitia:support:install  (points database.yml at the"
            say "    engines' migrations)"
          end
          say "  - bin/rails db:migrate"
          say "  - include Appwork::Chatter::Participant in each model that chats"
          say "  - In an initializer (config/initializers/appwork_chatter.rb):"
          say "      Appwork::Chatter.parent_controller = \"::ApplicationController\"  # defines current_participant"
          say "      Appwork::Chatter.participant_candidates = -> { ... }  # whom the current user may message"
          say ""
        end
      end
    end
  end
end
