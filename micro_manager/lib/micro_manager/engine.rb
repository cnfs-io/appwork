require "turbo-rails"
require "stimulus-rails"
require "importmap-rails"
require "tailwindcss-rails"

module MicroManager
  class Engine < ::Rails::Engine
    isolate_namespace MicroManager

    config.generators do |g|
      g.template_engine :tailwindcss
    end
  end
end
