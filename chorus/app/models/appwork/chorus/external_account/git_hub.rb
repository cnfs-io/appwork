require "net/http"
require "json"

module Appwork
  module Chorus
    class ExternalAccount
      # A GitHub organisation account. Keyless: `name` IS the org login, so there
      # are no settings to declare. The only acting kind today — it provisions a
      # remote repository so an agent has somewhere to push a new gem or app.
      #
      # No provisioner class and no Appwork::Chorus::GitHub namespace: the single action is
      # one HTTP POST, so it lives here directly. If a second operation ever appears
      # and this fattens, extraction is pain-driven then — not now.
      class GitHub < ExternalAccount
        API_VERSION = "2022-11-28".freeze

        # Create a remote repository in this org and return its SSH clone URL.
        # POSTs to the GitHub REST API (Config.github_api_url) with Config.github_token.
        # The token is never logged and never placed in the instrumentation payload;
        # the payload carries only the bounded org/repo names and an outcome label.
        def create_repository(repo_name, private: true)
          instrument(:create_repository, org: name, repo: repo_name) do |payload|
            body = post_repo(repo_name, private)
            payload[:outcome] = "ok"
            body.fetch("ssh_url")
          rescue StandardError
            payload[:outcome] = "failed"
            raise
          end
        end

        private

        # Issue the POST that creates the repo and return the parsed response Hash.
        # Thin and mockable so specs can stub it without touching the network. On a
        # non-2xx response, raise with status + GitHub's error message — never the
        # token or the full auth header (host/status only in any surfaced string).
        def post_repo(repo_name, is_private)
          token = Appwork::Chorus::Config.github_token.to_s
          raise "appwork_chorus github_token is not set (credentials appwork_chorus.github_token " \
                "or APPWORK_CHORUS_GITHUB_TOKEN)" if token.empty?

          uri = URI("#{Appwork::Chorus::Config.github_api_url}/orgs/#{name}/repos")
          request = Net::HTTP::Post.new(uri)
          request["Authorization"] = "Bearer #{token}"
          request["Accept"] = "application/vnd.github+json"
          request["User-Agent"] = "chorus"
          request["X-GitHub-Api-Version"] = API_VERSION
          request.body = JSON.generate(name: repo_name, private: is_private)

          response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
            http.request(request)
          end

          parsed = JSON.parse(response.body)
          return parsed if response.is_a?(Net::HTTPSuccess)

          message = parsed.is_a?(Hash) ? parsed["message"] : response.body
          raise "POST #{uri.host}/orgs/#{name}/repos failed (#{response.code}): #{message}"
        end
      end
    end
  end
end
