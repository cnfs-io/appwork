module Appwork
  module Chorus
    class ExternalAccount
      # A GitLab account. Data-only for now: it persists its targeting config and
      # takes no action. `name` is the account label; `group` selects the target
      # group new repos would live under.
      class Gitlab < ExternalAccount
        setting :group
      end
    end
  end
end
