require "partitia/support"
# Appwork::Chorus::ApplicationRecord includes Appwork::Okf::Consumer
require "appwork/okf"
require "turbo-rails"
require "stimulus-rails"
require "importmap-rails"
require "tailwindcss-rails"

module Appwork
  module Chorus
    class Engine < ::Rails::Engine
      isolate_namespace Appwork::Chorus
      Partitia::Support.plugins << self

      config.generators do |g|
        g.template_engine :tailwindcss
      end

      # Partitia::Support ships YamlSerializable as an `app/models/concerns` concern, but
      # partitia-support is a railtie (not an Engine), so its app paths never reach the
      # host's autoload roots. Appwork::Chorus::Curation is the first consumer, so add just
      # that concerns dir as an autoload root here — Zeitwerk then resolves
      # Partitia::Support::YamlSerializable from `partitia/support/yaml_serializable.rb`.
      # (Flagged in progress.md: the cleaner home is a central require in
      # partitia-support itself once a second consumer appears.)
      initializer "appwork_chorus.partitia_support_concerns", before: :set_autoload_paths do |app|
        concerns = File.join(Gem.loaded_specs["partitia-support"].full_gem_path, "app", "models", "concerns")
        app.config.autoload_paths << concerns
        app.config.eager_load_paths << concerns
      end

      # `github.rb` autoloads to Appwork::Chorus::ExternalAccount::GitHub (the GitHub STI
      # kind); teach the inflector the acronym so Zeitwerk resolves the file to the
      # capitalized constant rather than the default `Github`.
      initializer "appwork_chorus.inflections", before: :set_autoload_paths do
        ActiveSupport::Inflector.inflections(:en) do |inflect|
          inflect.acronym "GitHub"
        end
      end

      # Contribute Chorus model shortcuts to the console when partitia-dev is present.
      # Only loads in a console session (never web/job processes).
      console do
        return unless defined?(Partitia::Dev)

        Partitia::Dev.console do |c|
          c.namespace Appwork::Chorus, "c"
        end
      end
    end
  end
end
