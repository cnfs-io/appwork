# frozen_string_literal: true

require "partitia/support"

module Appwork
  module Chorus
    # Chorus' settings (anyway_config), so every value resolves from
    # config/appwork_chorus.yml -> credentials.appwork_chorus -> ENV["APPWORK_CHORUS_*"]
    # with one precedence, the family convention (partitia ARCHITECTURE §4: one config
    # class per engine).
    #
    # One SECRET lives here: github_token (ExternalAccount::GitHub's REST calls). Set it
    # in credentials (appwork_chorus.github_token) or APPWORK_CHORUS_GITHUB_TOKEN, never
    # in config/appwork_chorus.yml. Unset, a GitHub call raises before any request.
    #
    # A tenant's CURATION POSTURE is configuration, not data — it does not belong on
    # any model. It lives here as two knobs:
    #
    #   * curation_enabled       — whether chorus.org's curation is in force.
    #   * reputation_threshold   — the minimum reputation required when curation is on.
    #
    # # 004 default decision: curation_enabled defaults TRUE (curated by default),
    # reputation_threshold defaults 50 (a modest non-zero bar — reject the bottom
    # half of graded skills, admit nothing chorus.org flagged as trash). These are
    # the plumbing defaults; see progress.md.
    #
    # # 004 deferred: NO policy consumes these yet. How curation_enabled +
    # reputation_threshold actually gate/rank the catalog (and whether nil/unreviewed
    # passes when curation is on) is policy, deferred to a later plan. This class only
    # establishes where the knobs live.
    class Config < Partitia::Support::Config
      config_name :appwork_chorus   # -> config/appwork_chorus.yml, credentials.chorus, ENV["APPWORK_CHORUS_*"]

      # # 007 execution mode is CONFIGURATION, not a per-call dry_run: (§8). "Does the
      # agent run / do skills install" is a question the system asks at every layer
      # (CI, console-without-auth, later cost preview), so it is first-class posture.
      # Two switches, not one, because the npx install and the agent exec are separate
      # side effects worth toggling independently:
      #   * agents_live — false skips the `claude -p` exec (dry invoke; argv recorded)
      #   * skills_live — false skips the `npx skills` install (dry equip; argv recorded)
      # Both default TRUE (live); ENV flips them (APPWORK_CHORUS_AGENTS_LIVE / APPWORK_CHORUS_SKILLS_LIVE)
      # so CI runs dry and Roberto's authed console runs live, no code change.
      # # 009 execution environment (§6). Two more environment knobs:
      #   * workspace_root — where materialized Workspace directories live. Each
      #     Workspace IS a real directory (workspace_root/<id>): the run's cwd, the
      #     home for project-scoped skills, and where captured output lands. Default
      #     ~/.chorus/workspaces (outside any repo); a host points it at a tmpdir in
      #     CI or a durable path in production via APPWORK_CHORUS_WORKSPACE_ROOT. "~" is
      #     expanded where the path is used.
      #   * skill_copy — the `npx skills add --copy` toggle (copy vs symlink). A real
      #     environment preference: symlinks break in some sandboxes/containers, so we
      #     default to copy (the safe choice everywhere); APPWORK_CHORUS_SKILL_COPY=false opts
      #     back into lighter symlinks where they work. (`-y` is NOT config — it is an
      #     unconditional constant in the install argv.)
      attr_config curation_enabled: true, reputation_threshold: 50,
                  agents_live: true, skills_live: true,
                  workspace_root: "~/.chorus/workspaces", skill_copy: true,
                github_token: nil, github_api_url: "https://api.github.com"

      # anyway_config coerces string ENV/YAML values; keep these honestly typed.
      coerce_types curation_enabled: :boolean, reputation_threshold: :integer,
                   agents_live: :boolean, skills_live: :boolean,
                   skill_copy: :boolean
    end
  end
end
