require "turbo-rails"
require "stimulus-rails"
require "importmap-rails"
require "tailwindcss-rails"

module Okf
  class Engine < ::Rails::Engine
    isolate_namespace Okf

    config.generators do |g|
      g.template_engine :tailwindcss
    end

    # Make OKF's migrations visible to non-tenanted host apps in place (no
    # copying into the host's db/migrate). The standard engine railtie usually
    # appends this already; this keeps it explicit and idempotent.
    #
    # NOTE for ActiveRecord::Tenanted hosts: tenanted database configs read
    # migration paths from their own `migrations_paths` and fall back to a
    # hardcoded ["db/migrate"] when nil — they do NOT consult the app paths
    # below. So a tenanted host must list the engine path in its tenanted
    # config's `migrations_paths` in database.yml, e.g.:
    #
    #   primary:
    #     tenanted: true
    #     migrations_paths: <%%= ["db/migrate", Okf::Engine.root.join("db","migrate").to_s].inspect %>
    #
    # (Attempts to inject this automatically via base_configs proved unreliable
    # because the per-tenant migration_context does not pick up late mutations
    # to the base config.)
    initializer :append_okf_migrations do |app|
      okf_migrate_path = Okf::Engine.root.join("db", "migrate").to_s
      app_paths = app.config.paths["db/migrate"].to_a
      unless app_paths.include?(okf_migrate_path)
        app.config.paths["db/migrate"] << okf_migrate_path
      end
    end

    # Auto-wire OKF models into a tenanted host's per-tenant connection.
    #
    # OKF models inherit from Okf::ApplicationRecord (abstract, extends
    # ActiveRecord::Base), not from the host's tenanted ApplicationRecord. With
    # ActiveRecord::Tenanted present, that means they'd use a raw untenanted
    # connection and raise NoTenantError. `subtenant_of` attaches the OKF model
    # subtree to the host's tenanted connection class; applied to the abstract
    # base, it cascades to Bundle, Concept, and RootBundle.
    #
    # Fully guarded so OKF stays tenancy-agnostic and drop-in for plain Rails
    # apps:
    #   - only acts when ActiveRecord::Tenanted is loaded
    #   - only acts when Okf::ApplicationRecord responds to subtenant_of
    #   - only acts when the host defines a top-level ApplicationRecord to
    #     subtenant under
    #
    # Runs in to_prepare so it re-applies across development code reloading
    # (reloaded model constants otherwise lose the wiring).
    config.to_prepare do
      if defined?(ActiveRecord::Tenanted) &&
         defined?(Okf::ApplicationRecord) &&
         Okf::ApplicationRecord.respond_to?(:subtenant_of) &&
         defined?(::ApplicationRecord)
        Okf::ApplicationRecord.subtenant_of "ApplicationRecord"
      end
    end
  end
end
