require "turbo-rails"
require "stimulus-rails"
require "importmap-rails"
require "tailwindcss-rails"

module Okf
  class Engine < ::Rails::Engine
    isolate_namespace Okf

    config.generators do |g|
      g.template_engine :tailwindcss
    end
  end
end
