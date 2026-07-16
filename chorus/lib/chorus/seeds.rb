module Chorus
  # Idempotent seed for the 007 console scenario: a "frontend-builder" agent
  # equipped to build a Phlex table component (§7). Runnable from a host app via
  # `bin/rails db:seed` or `rake chorus:seed`. Creates RECORDS ONLY — it never
  # shells out (no npx install, no agent run); invocation is a console/manual act.
  #
  # Host-agnostic: the bare workable a Workspace occupies is a HOST model, so the
  # host passes it in (`seed!(workable: ...)`) — Chorus names no host constant.
  #
  # The Role's skill requirements are REAL skills.sh names (both from
  # vercel-labs/agent-skills), so an authed live run genuinely installs them. They
  # are framework-agnostic markup/design skills — applicable to a Phlex component
  # because Phlex emits HTML. (The two evaluator roles that will later score this
  # Artifact from divergent perspectives are deferred to the goal-4 plan.)
  module Seeds
    module_function

    # Real skills.sh name from vercel-labs/agent-skills — resolvable/installable to
    # `-a claude-code`. `web-design-guidelines` audits rendered markup (semantic
    # HTML, ARIA, keyboard nav, contrast) — framework-agnostic, so it applies to a
    # Phlex component (Phlex emits HTML). NOT vercel-react-best-practices: that
    # scores React perf and would judge Ruby against React rules (§7).
    #
    # NOTE: `frontend-design` is NOT in vercel-labs/agent-skills — it lives in
    # `anthropics/skills`. The stubbed SkillResolver resolves every requirement
    # against vercel-labs/agent-skills, so a multi-repo requirement can't be
    # expressed until the resolver learns per-name repo resolution (the deferred
    # curation-policy work). Single skill for now keeps the resolver stub honest.
    SEED_SKILLS = %w[web-design-guidelines].freeze

    def seed!(workable: nil)
      profile = AgentProfile::ClaudeCode.find_or_create_by!(name: "Claude Code")

      agent = Agent.find_or_create_by!(name: "Frontend Builder") { |a| a.agent_profile = profile }
      agent.update!(agent_profile: profile) if agent.agent_profile.nil?

      role = Role.find_or_create_by!(name: "frontend-builder") do |r|
        r.description = "Equips an agent to build UI components: markup, a11y, and " \
                        "front-end design skills."
      end
      SEED_SKILLS.each { |name| role.skill_requirements.find_or_create_by!(name: name) }

      workspace = Workspace.find_or_create_by!(name: "Frontend") do |w|
        w.description = "Home for the frontend-builder agent's runs and artifacts."
      end
      # Occupy a bare workable if the host provided one (Workspace occupies at most
      # one at a time; only set it when currently free).
      workspace.update!(workable: workable) if workable && workspace.workable.nil?

      { profile: profile, agent: agent, role: role, workspace: workspace }
    end
  end
end
