FactoryBot.define do
  # Base ExternalAccount is abstract in practice (validates :type present); build
  # concrete kinds via the subclass factories below. Names are randomized to
  # satisfy the unique [type, name] index.
  factory :chorus_external_account_github, class: "Chorus::ExternalAccount::GitHub" do
    name { "acme-org-#{rand(10_000)}" }
  end

  factory :chorus_external_account_gitlab, class: "Chorus::ExternalAccount::Gitlab" do
    name { "acme-group-#{rand(10_000)}" }
    group { "acme/platform" }
  end

  factory :chorus_external_account_aws, class: "Chorus::ExternalAccount::Aws" do
    name { "acme-aws-#{rand(10_000)}" }
    account_id { "123456789012" }
    region { "us-east-1" }
    default_role_arn { "arn:aws:iam::123456789012:role/chorus" }
  end

  factory :chorus_external_account_google_cloud, class: "Chorus::ExternalAccount::GoogleCloud" do
    name { "acme-gcp-#{rand(10_000)}" }
    project_id { "acme-project" }
    service_account_email { "chorus@acme-project.iam.gserviceaccount.com" }
  end
end
