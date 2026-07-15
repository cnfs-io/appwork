require "turbo-rails"
require "stimulus-rails"
require "importmap-rails"
require "tailwindcss-rails"

module Gtd
  class Engine < ::Rails::Engine
    isolate_namespace Gtd

    config.generators do |g|
      g.template_engine :tailwindcss
    end
  end
end
