module Appwork
  module Chorus
    # A third-party service account a tenant holds: a GitHub org, GitLab group, AWS
    # account, GCP project. STI on `type`; `name` is the account identifier (e.g. the
    # GitHub org login). Shared columns are minimal — per-vendor config lives in the
    # serialized `settings` bag so the table carries no per-vendor columns.
    #
    # STI is justified by BEHAVIOUR, not data: the subclasses differ in what they
    # *do*. Only GitHub acts today (creates repos, via #create_repository); the other
    # three are data-only control records that persist their targeting config and
    # nothing else. Provisioning is deliberately NOT a universal interface on the base
    # (unlike Source's transport trio) — only the kinds that act declare an action.
    #
    # Account-scoped by tenancy (one physical DB per Account), so no owner column.
    class ExternalAccount < ApplicationRecord
      serialize :settings, coder: YAML, type: Hash

      validates :type, presence: true
      validates :name, presence: true

      after_initialize { self.settings ||= {} }

      # Declares a reader/writer backed by a key in the serialized `settings` bag,
      # so subclasses expose their vendor-specific config as first-class accessors
      # without adding columns. e.g. `setting :region` -> #region / #region=.
      def self.setting(*names)
        names.each do |name|
          define_method(name) { settings[name.to_s] }
          define_method(:"#{name}=") { |value| self.settings = settings.merge(name.to_s => value) }
        end
      end

      private

      # Emit all ExternalAccount instrumentation under the `partitia_appwork.external_account.*`
      # prefix, regardless of STI subclass. The default Instrumentable#instrument
      # derives the subject from the demodulized class name, so a three-level subclass
      # like Appwork::Chorus::ExternalAccount::GitHub would emit
      # "partitia_appwork.git_hub.<verb>". Pinning the subject to "Appwork::Chorus::ExternalAccount"
      # gives every kind a stable "partitia_appwork.external_account.<verb>" name.
      def instrument(verb, **payload, &block)
        name = Partitia::Support::Instrumentable.event_name("Appwork::Chorus::ExternalAccount", verb)
        ActiveSupport::Notifications.instrument(name, **payload, &block)
      end
    end
  end
end
