require "partitia/support"
require "turbo-rails"
require "stimulus-rails"
require "importmap-rails"
require "tailwindcss-rails"

module Appwork
  module Okf
    class Engine < ::Rails::Engine
      isolate_namespace Appwork::Okf

      config.generators do |g|
        g.template_engine :tailwindcss
      end
      Partitia::Support.plugins << self

      # Load console shortcuts/commands when partitia-dev is present.
      # Only loads in a console session (never web/job processes).
      console do
        Partitia::Dev.console do |c|
          c.namespace(module_parent, "o")
        end if defined?(Partitia::Dev)
      end
    end
  end
end
