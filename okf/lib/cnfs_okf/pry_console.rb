module CnfsOkf
  # OKF console enhancements contributed to cnfs_dev's console. cnfs_dev exposes
  # Activated from the Engine's `console` block (development/test).
  module PryConsole
    module_function

    def install!
      return unless defined?(CnfsDev)

      CnfsDev.console do |c|
        register_shortcuts(c)
        register_sync(c)
        register_reset(c)
      end
    end

    # Register the CnfsOkf model namespace; cnfs_dev's ShortcutPlanner
    # auto-discovers every ActiveRecord model under CnfsOkf (Bundle, Concept,
    # ViewPort, ...) and derives a shortcut code for each under prefix "o".
    # Contributes:
    #   ob, oba, ...   -> CnfsOkf::Bundle shortcuts (auto-discovered)
    #   oc, oca, ...   -> CnfsOkf::Concept shortcuts
    #   ov, ova, ...   -> CnfsOkf::ViewPort shortcuts
    def register_shortcuts(c) = c.namespace(module_parent, "o")
  end
end
