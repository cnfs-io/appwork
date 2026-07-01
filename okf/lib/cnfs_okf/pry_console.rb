module CnfsOkf
  # OKF console enhancements contributed to cnfs_dev's console. cnfs_dev exposes
  # the CnfsDev.console facade; this fills in the OKF specifics. Activated from
  # the Engine's `console` block (development/test).
  #
  # Contributes:
  #   vb, vba, ...   -> CnfsOkf::Bundle shortcuts
  #   vc, vca, ...   -> CnfsOkf::Concept shortcuts
  #   (dummy app)    -> Goal/Issue/Organization/Project/Strategy shortcuts
  #   sync           -> run CnfsOkf::SyncService over every bundle (when present)
  #   before_reset   -> clear tmp/bundles before each reset_project!
  #   reset_task     -> append okf:sync to the reset chain (when present)
  module PryConsole
    module_function

    # Always-available OKF model shortcuts (prefix => model name under CnfsOkf).
    SHORTCUTS = {
      "b" => "Bundle",
      "c" => "Concept"
    }.freeze

    # Shortcuts present only in the dummy/host app (top-level models).
    DUMMY_SHORTCUTS = {
      "g" => "Goal",
      "i" => "Issue",
      "o" => "Organization",
      "p" => "Project",
      "s" => "Strategy"
    }.freeze

    def install!
      return unless defined?(CnfsDev)

      CnfsDev.console do |c|
        register_shortcuts(c)
        register_sync(c)
        register_reset(c)
      end
    end

    # OKF model shortcuts (namespaced) plus the dummy/host top-level models,
    # each added only when the constant actually resolves.
    def register_shortcuts(c)
      SHORTCUTS.each do |prefix, model_name|
        next unless CnfsOkf.const_defined?(model_name)

        c.shortcuts(prefix, CnfsOkf.const_get(model_name))
      end

      DUMMY_SHORTCUTS.each do |prefix, model_name|
        next unless Object.const_defined?(model_name)

        c.shortcuts(prefix, Object.const_get(model_name))
      end
    end

    # `sync` runs the OKF sync service across every bundle. Inert until
    # CnfsOkf::SyncService exists (guarded at call time so it tracks the
    # service being built later in the same session-less gem load).
    def register_sync(c)
      c.command(:sync) do
        unless defined?(CnfsOkf::SyncService)
          puts "[okf-sync] CnfsOkf::SyncService is not defined yet"
          next
        end

        CnfsOkf::Bundle.all.each do |bundle|
          result = CnfsOkf::SyncService.new(bundle).call
          puts "[okf-sync] bundle=#{bundle.id} (#{bundle.name}): #{result.summary_line}"
          result.problems.each do |p|
            puts "[okf-sync]   #{p.kind} #{p.describe}"
          end
        end
      end
    end

    # Clear the generated bundles dir before each reset, and (when the sync
    # service/task exist) append okf:sync to the reset chain.
    def register_reset(c)
      c.before_reset do
        target = Rails.root.join("tmp/bundles")
        target.rmtree if target.exist?
      end

      c.reset_task("okf:sync") if defined?(CnfsOkf::SyncService)
    end
  end
end
