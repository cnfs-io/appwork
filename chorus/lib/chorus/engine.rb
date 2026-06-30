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
  end
end
