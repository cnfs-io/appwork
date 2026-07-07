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

    # Load console shortcuts/commands when cnfs_dev is present.
    # Only loads in a console session (never web/job processes).
    console do
      CnfsDev.console do |c|
        c.namespace(module_parent, "o")
      end if defined?(CnfsDev)
    end
  end
end
