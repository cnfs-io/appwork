require "turbo-rails"
require "stimulus-rails"
require "importmap-rails"
require "tailwindcss-rails"

module Chatter
  class Engine < ::Rails::Engine
    isolate_namespace Chatter

    config.generators do |g|
      g.template_engine :tailwindcss
    end
  end
end
