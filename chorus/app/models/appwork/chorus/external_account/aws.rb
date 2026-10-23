module Chorus
  class ExternalAccount
    # An AWS account. Data-only for now: it persists non-secret *targeting* data
    # only. When AWS eventually acts, credentials resolve from the AWS SDK's own
    # credential chain in the standard environment — never modeled here, never in
    # the settings bag.
    class Aws < ExternalAccount
      setting :account_id, :region, :default_role_arn
    end
  end
end
