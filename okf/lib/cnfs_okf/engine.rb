require "cnfs_support"
require "turbo-rails"
require "stimulus-rails"
require "importmap-rails"
require "tailwindcss-rails"

module CnfsOkf
  class Engine < ::Rails::Engine
    isolate_namespace CnfsOkf

    config.generators do |g|
      g.template_engine :tailwindcss
    end
    CnfsSupport.plugins << self

    # Contribute OKF console shortcuts/commands when cnfs_dev is present.
    # Only loads in a console session (never web/job processes).
    console do
      require "cnfs_okf/pry_console"
      CnfsOkf::PryConsole.install!
    end
  end
end
