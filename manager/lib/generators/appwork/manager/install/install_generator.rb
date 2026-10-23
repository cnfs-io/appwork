require "rails/generators/base"

module Appwork
  module Manager
    module Generators
      # Wires a host Rails app for appwork-manager, Manager (strategy, goals, projects, tickets: OKF consumers, Chorus workables):
      #
      #   bin/rails generate appwork:manager:install
      #
      # appwork-manager has no routes to mount and no host files to write. Its migrations reach
      # the app through partitia-support's registry (Partitia::Support.migrations_paths in
      # config/database.yml), never by copying, so this checks that wiring and prints what
      # the host still has to do.
      #
      # Idempotent: it writes nothing, so a second run changes nothing and asks nothing.
      class InstallGenerator < Rails::Generators::Base
        DATABASE_YML = "config/database.yml".freeze
        REGISTRY = "Partitia::Support.migrations_paths".freeze

        desc "Check database.yml reads appwork-manager's migrations from the partitia-support " \
             "registry, and print what the host still has to do."

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
          say "appwork-manager installed. Still to do:", :green
          unless @registry_wired
            say "  - bin/rails generate partitia:support:install  (points database.yml at the"
            say "    engines' migrations)"
          end
          say "  - bin/rails db:migrate"
          say "  - Run appwork:okf:install and appwork:chorus:install too (manager's models are"
          say "    OKF consumers and Chorus workables)."
          say ""
        end
      end
    end
  end
end
