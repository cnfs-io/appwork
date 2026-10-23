require "partitia/support"
# Manager models are OKF consumers and Chorus workables
require "appwork/okf"
require "appwork/chorus"
require "turbo-rails"
require "stimulus-rails"
require "importmap-rails"
require "tailwindcss-rails"

module Appwork
  module Manager
    class Engine < ::Rails::Engine
      isolate_namespace Appwork::Manager
      Partitia::Support.plugins << self

      config.generators do |g|
        g.template_engine :tailwindcss
      end
    end
  end
end
