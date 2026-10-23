require "rails_helper"

RSpec.describe Appwork::Chorus::ExternalAccount, type: :model do
  describe "the STI base" do
    it "cannot be persisted without a concrete type" do
      base = Appwork::Chorus::ExternalAccount.new(name: "acme")
      expect(base).not_to be_valid
      expect(base.errors[:type]).to be_present
    end

    it "requires a name" do
      account = build(:appwork_chorus_external_account_github, name: nil)
      expect(account).not_to be_valid
      expect(account.errors[:name]).to be_present
    end

    it "enforces uniqueness of [type, name]" do
      create(:appwork_chorus_external_account_github, name: "acme")
      dup = build(:appwork_chorus_external_account_github, name: "acme")
      expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "the settings bag" do
    it "defaults to an empty hash" do
      expect(Appwork::Chorus::ExternalAccount::GitHub.new.settings).to eq({})
    end

    it "round-trips a declared accessor for a data-only subtype" do
      account = create(:appwork_chorus_external_account_aws)
      expect(account.account_id).to eq("123456789012")
      expect(account.reload.settings).to include("account_id" => "123456789012")
    end

    it "does not add per-vendor columns to the table" do
      columns = Appwork::Chorus::ExternalAccount.column_names
      expect(columns).not_to include("group", "account_id", "region", "project_id")
    end
  end

  describe "STI resolution" do
    it "resolves the concrete subclass from the type column" do
      github = create(:appwork_chorus_external_account_github)
      expect(Appwork::Chorus::ExternalAccount.find(github.id)).to be_a(Appwork::Chorus::ExternalAccount::GitHub)
    end

    it "has valid factories for every subtype" do
      expect(build(:appwork_chorus_external_account_github)).to be_valid
      expect(build(:appwork_chorus_external_account_gitlab)).to be_valid
      expect(build(:appwork_chorus_external_account_aws)).to be_valid
      expect(build(:appwork_chorus_external_account_google_cloud)).to be_valid
    end
  end
end

RSpec.describe Appwork::Chorus::ExternalAccount::GitHub, type: :model do
  # Coordination only: verify GitHub issues the right HTTP call and returns the
  # clone URL, with the network stubbed. Efficacy (a real repo created against
  # the real GitHub API) is a host-app concern, out of Chorus's testing scope.

  # A sentinel token wired through Appwork::Chorus::Config so the secret-hygiene
  # assertions can prove it never leaks into a payload or an error string.
  SENTINEL_TOKEN = "SECRET-TOKEN".freeze

  before do
    allow(Appwork::Chorus::Config).to receive(:github_token).and_return(SENTINEL_TOKEN)
  end

  # Build a real Net::HTTPResponse of the given class with a canned body, so the
  # `is_a?(Net::HTTPSuccess)` branch in #post_repo is exercised for real.
  def build_response(klass, code, body)
    response = klass.new("1.1", code, "message")
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, body)
    response
  end

  # Stub the Net::HTTP boundary to return `response` and capture the request that
  # was issued. Returns the array the captured request lands in.
  def stub_http(response)
    captured = []
    fake_http = instance_double(Net::HTTP)
    allow(fake_http).to receive(:request) { |req| captured << req; response }
    allow(Net::HTTP).to receive(:start) { |*_args, &block| block.call(fake_http) }
    captured
  end

  describe "#create_repository" do
    it "returns the new repo's ssh clone URL" do
      account = create(:appwork_chorus_external_account_github)
      stub_http(build_response(Net::HTTPCreated, "201",
                               { "ssh_url" => "git@github.com:acme/new-repo.git" }.to_json))

      expect(account.create_repository("new-repo")).to eq("git@github.com:acme/new-repo.git")
    end

    it "POSTs to the org's repos endpoint carrying the Bearer token" do
      account = create(:appwork_chorus_external_account_github, name: "acme-org")
      captured = stub_http(build_response(Net::HTTPCreated, "201",
                                          { "ssh_url" => "git@github.com:acme/r.git" }.to_json))

      account.create_repository("r")

      request = captured.first
      expect(request).to be_a(Net::HTTP::Post)
      expect(request.path).to eq("/orgs/acme-org/repos")
      expect(request["Authorization"]).to eq("Bearer #{SENTINEL_TOKEN}")
      expect(request["X-GitHub-Api-Version"]).to eq("2022-11-28")
      expect(JSON.parse(request.body)).to eq("name" => "r", "private" => true)
    end

    it "sends private: false when asked for a public repo" do
      account = create(:appwork_chorus_external_account_github)
      captured = stub_http(build_response(Net::HTTPCreated, "201",
                                          { "ssh_url" => "git@github.com:acme/r.git" }.to_json))

      account.create_repository("r", private: false)

      expect(JSON.parse(captured.first.body)).to include("private" => false)
    end

    it "raises with the status and GitHub's message on a non-2xx response" do
      account = create(:appwork_chorus_external_account_github, name: "acme-org")
      stub_http(build_response(Net::HTTPUnprocessableEntity, "422",
                               { "message" => "name already exists on this account" }.to_json))

      expect { account.create_repository("dupe") }
        .to raise_error(/422.*name already exists/m)
    end

    it "refuses to call GitHub when no token is set" do
      allow(Appwork::Chorus::Config).to receive(:github_token).and_return(nil)
      account = create(:appwork_chorus_external_account_github, name: "acme-org")
      expect(Net::HTTP).not_to receive(:start)

      expect { account.create_repository("new-gem") }.to raise_error(/github_token is not set/)
    end
  end

  describe "instrumentation and secret hygiene" do
    # Collect every notification matching `pattern` fired during the block as
    # [name, payload] pairs. Mirrors source_spec.rb's capture_events; the pattern
    # may be a String or a Regexp.
    def capture_events(pattern)
      events = []
      callback = ->(name, _start, _finish, _id, payload) { events << [ name, payload ] }
      ActiveSupport::Notifications.subscribed(callback, pattern) { yield }
      events
    end

    # Every ExternalAccount kind emits under the `partitia_appwork.external_account.*`
    # prefix — pinned in the STI base so a three-level subclass name does not leak
    # `git_hub` into the component tag (the same pinning trick Source uses).
    CREATE_REPO_EVENT = "partitia_appwork.external_account.create_repository".freeze

    it "emits one create_repository event under the pinned subject" do
      account = create(:appwork_chorus_external_account_github, name: "acme-org")
      stub_http(build_response(Net::HTTPCreated, "201",
                               { "ssh_url" => "git@github.com:acme/r.git" }.to_json))

      events = capture_events(CREATE_REPO_EVENT) { account.create_repository("r") }

      expect(events.size).to eq(1)
      name, payload = events.first
      expect(name).to eq(CREATE_REPO_EVENT)
      expect(name).not_to include("git_hub")
      expect(payload).to include(org: "acme-org", repo: "r", outcome: "ok")
    end

    it "marks the outcome failed and stamps the exception when the call fails" do
      account = create(:appwork_chorus_external_account_github)
      stub_http(build_response(Net::HTTPForbidden, "403", { "message" => "forbidden" }.to_json))

      events = capture_events(CREATE_REPO_EVENT) do
        expect { account.create_repository("r") }.to raise_error(/403/)
      end

      _name, payload = events.first
      expect(payload[:outcome]).to eq("failed")
      expect(payload[:exception]).to be_present
    end

    # The load-bearing assertion: a green "returns the ssh_url" test passes whether
    # or not the token leaks. This proves the sentinel never reaches any payload.
    it "never places the token in the instrumentation payload (success path)" do
      account = create(:appwork_chorus_external_account_github)
      stub_http(build_response(Net::HTTPCreated, "201",
                               { "ssh_url" => "git@github.com:acme/r.git" }.to_json))

      events = capture_events(CREATE_REPO_EVENT) { account.create_repository("r") }

      expect(events).not_to be_empty
      events.each do |_name, payload|
        expect(payload.inspect).not_to include(SENTINEL_TOKEN)
      end
    end

    # ...and neither the payload nor the surfaced error carries it on failure —
    # the error string is built from host/status/message only.
    it "never leaks the token into the payload or the raised error (failure path)" do
      account = create(:appwork_chorus_external_account_github)
      stub_http(build_response(Net::HTTPUnprocessableEntity, "422",
                               { "message" => "boom" }.to_json))

      raised = nil
      events = capture_events(CREATE_REPO_EVENT) do
        begin
          account.create_repository("r")
        rescue StandardError => e
          raised = e
        end
      end

      expect(raised).to be_present
      expect(raised.message).not_to include(SENTINEL_TOKEN)
      events.each do |_name, payload|
        expect(payload.inspect).not_to include(SENTINEL_TOKEN)
      end
    end
  end
end
