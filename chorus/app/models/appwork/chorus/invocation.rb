module Appwork
  module Chorus
    # The invocation seam's coordinator: given an Agent (which IS its runtime), a Role
    # (a capability loadout), and a task, it resolves the role's skills, equips the
    # agent's runtime, invokes it, and persists a durable Result + Artifact — every
    # run, live or dry (§5). Returns the Result.
    #
    #   resolve (SkillResolver) -> equip (Equipper) -> invoke (Agent) ->
    #   persist Result + Artifact
    #
    # It honors the §8 config switches THROUGH the collaborators: the Equipper gates
    # on skills_live, the Agent gates on agents_live. The coordinator records which
    # switches were in effect onto the Result so a dry run is fully inspectable.
    #
    # Console entry point (§7) — after `bin/rails db:seed`, in `bin/rails console`:
    #
    #   agent = Appwork::Chorus::Agent.find_by(name: "Frontend Builder")
    #   role  = Appwork::Chorus::Role.find_by(name: "frontend-builder")
    #   task  = "Build a Phlex searchable, sortable table component for Rails ..."
    #   result = Appwork::Chorus::Invocation.new(agent:, role:, task:).call
    #   result.success?       # => true/false
    #   result.full_messages  # => [...]
    #   result.artifact       # => the built component, durable
    #   result.recorded_argv  # => the equip + invoke argv (would-run in dry mode)
    #
    # Dry by default when APPWORK_CHORUS_AGENTS_LIVE=false; a REAL `claude -p` build when
    # APPWORK_CHORUS_AGENTS_LIVE=true (and Roberto is authed). Either way Result + Artifact
    # are persisted and queryable (Appwork::Chorus::Result.last, Appwork::Chorus::Artifact.last).
    class Invocation
      def initialize(agent:, role:, task:, workspace: nil)
        @agent     = agent
        @role      = role
        @task      = task
        # Agent carries no workspace FK (discovered host-side); for the console
        # scenario the seed leaves exactly one Workspace, so default to it. Specs
        # pass one explicitly.
        @workspace = workspace || Appwork::Chorus::Workspace.first
      end

      def call
        # Agent IS its runtime adapter now (plan 011 §2 collapsed AgentAdapter in). This
        # coordinator is inert dead code (its spec was retired in 010); the foreman loop
        # replaces it. Kept rename-through only so it loads.
        adapter = @agent

        result = Appwork::Chorus::Result.new(
          workspace:   @workspace,
          agents_live: Appwork::Chorus::Config.agents_live,
          skills_live: Appwork::Chorus::Config.skills_live
        )

        resolved = SkillResolver.new(@role).resolve
        Equipper.new(adapter: adapter, result: result, workspace: @workspace).equip(resolved)

        adapter.invoke(task: @task, role: @role, result: result, workspace: @workspace)

        result.artifact = capture_artifact
        # Respect what equip/invoke recorded: an operational failure already flipped
        # success to false (§5). Only when nothing failed do we mark it — success ==
        # "no messages accumulated", the way `valid?` gates `save`.
        result.success = result.empty? if result.success.nil?
        result.save!
        result
      end

      private

      # Record the run into a durable Artifact on the workspace — OPAQUELY (§7). Agent
      # output lands in the workspace directory (the run's cwd), so the Artifact only
      # notes that the run happened and points at that location; it carries no content
      # and no version model. A richer Source/commit-SHA-backed Artifact is a dedicated
      # deferred plan — 009 builds nothing that plan would have to tear out.
      def capture_artifact
        live = Appwork::Chorus::Config.agents_live
        @workspace.artifacts.create!(
          name:        "agent-output-#{Time.current.to_i}",
          kind:        "agent_output",
          # Live: point at the workspace dir where the run's output landed. Dry: no run,
          # so a marked placeholder with no locator.
          locator:     live ? @workspace.pathname.to_s : nil,
          description: live ? "agent run — output in the workspace directory" : "(dry run — agent not executed)"
        )
      end
    end
  end
end
