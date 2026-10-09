require "cnfs_support"
# The two flanking layers. Requiring both here makes Gtd the composition root
# (ADR 0005): CnfsOkf::Consumer + has_one_okf come from okf, the Placement /
# Board / Column machinery + Kanban components from cnfs_ui. cnfs_ui already
# requires the UI stack (turbo/stimulus/importmap/tailwindcss/phlex), so we don't
# re-require it here.
require "cnfs_okf"
require "cnfs_ui"

module Gtd
  class Engine < ::Rails::Engine
    isolate_namespace Gtd
    CnfsSupport.plugins << self

    config.generators do |g|
      g.template_engine :tailwindcss
    end

    # Load console shortcuts/commands when cnfs_dev is present.
    # Only loads in a console session (never web/job processes).
    console do
      CnfsDev.console do |c|
        c.namespace(module_parent, "g")
      end if defined?(CnfsDev)
    end
  end
end
