require "partitia/support"
# The two flanking layers. Requiring both here makes Gtd the composition root
# (ADR 0005): Appwork::Okf::Consumer + has_one_okf come from okf, the Placement /
# Board / Column machinery + Kanban components from partitia-ui. partitia-ui already
# requires the UI stack (turbo/stimulus/importmap/tailwindcss/phlex), so we don't
# re-require it here.
require "appwork/okf"
require "partitia/ui"

module Appwork
  module Gtd
    class Engine < ::Rails::Engine
      isolate_namespace Appwork::Gtd
      Partitia::Support.plugins << self

      config.generators do |g|
        g.template_engine :tailwindcss
      end

      # Load console shortcuts/commands when partitia-dev is present.
      # Only loads in a console session (never web/job processes).
      console do
        Partitia::Dev.console do |c|
          c.namespace(module_parent, "g")
        end if defined?(Partitia::Dev)
      end
    end
  end
end
