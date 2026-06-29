require "okf/version"
require "okf/engine"

module Okf
  # Root directory under which non-absolute bundle paths are materialized.
  def self.bundles_root
    Rails.root.join("tmp/bundles")
  end

  # Absolute path to OKF's migrations. Public so a host can register it wherever
  # it needs (e.g. into a tenant migration-paths registry read by database.yml).
  def self.migrations_path
    File.expand_path("../db/migrate", __dir__)
  end
end

# Soft, convention-based registration: if the host app defines a
# TenantMigrations registry (a plain module loaded before database.yml's ERB),
# contribute OKF's migration path so tenanted databases pick it up. This runs
# at gem-load time — before database.yml is evaluated — which is required since
# Rails 7.1+ reads database.yml before initializers.
#
# Entirely optional: OKF works fine in hosts that don't use the registry (plain
# or non-tenanted apps). OKF knows nothing about the host beyond this one
# duck-typed hook.
if defined?(TenantMigrations) && TenantMigrations.respond_to?(:register)
  TenantMigrations.register(Okf.migrations_path)
end
