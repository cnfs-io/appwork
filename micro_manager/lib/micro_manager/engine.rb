require "cnfs_support"
require "turbo-rails"
require "stimulus-rails"
require "importmap-rails"
require "tailwindcss-rails"

module MicroManager
  class Engine < ::Rails::Engine
    isolate_namespace MicroManager
    CnfsSupport.plugins << self

    config.generators do |g|
      g.template_engine :tailwindcss
    end
  end
end
