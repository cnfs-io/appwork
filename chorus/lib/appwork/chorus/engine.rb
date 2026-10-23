require "cnfs_support"
require "cnfs_dev"
require "turbo-rails"
require "stimulus-rails"
require "importmap-rails"
require "tailwindcss-rails"

module Chorus
  class Engine < ::Rails::Engine
    isolate_namespace Chorus
    CnfsSupport.plugins << self

    config.generators do |g|
      g.template_engine :tailwindcss
    end

    # CnfsSupport ships YamlSerializable as an `app/models/concerns` concern, but
    # cnfs_support is a railtie (not an Engine), so its app paths never reach the
    # host's autoload roots. Chorus::Curation is the first consumer, so add just
    # that concerns dir as an autoload root here — Zeitwerk then resolves
    # CnfsSupport::YamlSerializable from `cnfs_support/yaml_serializable.rb`.
    # (Flagged in progress.md: the cleaner home is a central require in
    # cnfs_support itself once a second consumer appears.)
    initializer "chorus.cnfs_support_concerns", before: :set_autoload_paths do |app|
      concerns = File.join(Gem.loaded_specs["cnfs_support"].full_gem_path, "app", "models", "concerns")
      app.config.autoload_paths << concerns
      app.config.eager_load_paths << concerns
    end

    # `github.rb` autoloads to Chorus::ExternalAccount::GitHub (the GitHub STI
    # kind); teach the inflector the acronym so Zeitwerk resolves the file to the
    # capitalized constant rather than the default `Github`.
    initializer "chorus.inflections", before: :set_autoload_paths do
      ActiveSupport::Inflector.inflections(:en) do |inflect|
        inflect.acronym "GitHub"
      end
    end

    # Contribute Chorus model shortcuts to the console when cnfs_dev is present.
    # Only loads in a console session (never web/job processes).
    console do
      return unless defined?(CnfsDev)

      CnfsDev.console do |c|
        c.namespace Chorus, "c"
      end
    end
  end
end
