require "rails/generators/base"

module Appwork
  module Chorus
    module Generators
      # Wires a host Rails app for appwork-chorus, Chorus (agents, roles, skills, work orders):
      #
      #   bin/rails generate appwork:chorus:install
      #
      # appwork-chorus has no routes to mount and no host files to write. Its migrations reach
      # the app through partitia-support's registry (Partitia::Support.migrations_paths in
      # config/database.yml), never by copying, so this checks that wiring and prints what
      # the host still has to do.
      #
      # Idempotent: it writes nothing, so a second run changes nothing and asks nothing.
      class InstallGenerator < Rails::Generators::Base
        DATABASE_YML = "config/database.yml".freeze
        REGISTRY = "Partitia::Support.migrations_paths".freeze

        desc "Check database.yml reads appwork-chorus's migrations from the partitia-support " \
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
          say "appwork-chorus installed. Still to do:", :green
          unless @registry_wired
            say "  - bin/rails generate partitia:support:install  (points database.yml at the"
            say "    engines' migrations)"
          end
          say "  - bin/rails db:migrate"
          say "  - Settings (optional): config/appwork_chorus.yml, credentials.appwork_chorus or"
          say "    APPWORK_CHORUS_* (agents_live, skills_live, workspace_root, skill_copy, curation_*)."
          say "  - GitHub accounts need a token: credentials appwork_chorus.github_token or"
          say "    APPWORK_CHORUS_GITHUB_TOKEN (a secret: never in config/appwork_chorus.yml)."
          say "  - Include Appwork::Chorus::Workable in the models work is done on."
          say "  - Example records: bin/rails appwork:chorus:seed"
          say ""
        end
      end
    end
  end
end
