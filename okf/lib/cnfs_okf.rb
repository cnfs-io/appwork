require "cnfs_okf/version"
require "cnfs_okf/engine"

module CnfsOkf
  # Root directory under which non-absolute bundle paths are materialized.
  def self.bundles_root
    Rails.root.join("tmp/bundles")
  end
end
