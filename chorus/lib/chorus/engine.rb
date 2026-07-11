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
