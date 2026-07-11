module Chorus
  class ExternalAccount
    # A Google Cloud account. Data-only for now: it persists non-secret targeting
    # data only. When GCP eventually acts, credentials resolve from the Google SDK's
    # own credential chain in the standard environment — never modeled here, never
    # in the settings bag.
    class GoogleCloud < ExternalAccount
      setting :project_id, :service_account_email
    end
  end
end
