module Chorus
  class AgentAdapter
    # The Claude Code CLI runtime. Skills mount under the "claude-code" agent key,
    # project-scoped INTO the workspace directory (§4 — not ~/.claude); invocation is
    # `claude -p <task>` in headless/print mode, run with the workspace as cwd. Argv
    # construction is the tested surface; the exec itself only runs live
    # (Config#agents_live) and is a manual console act.
    class ClaudeCode < AgentAdapter
      def skills_agent_key = "claude-code"

      def invoke(task:, role:, result:, workspace:)
        run_invocation(invocation_argv(task), result, workspace: workspace)
      end

      private

      # `claude -p <task>` — headless print mode: one prompt, non-interactive.
      # Deliberately minimal; role/skill context arrives via the equipped skills
      # (mounted by the Equipper), not stuffed into the argv here.
      def invocation_argv(task)
        [ "claude", "-p", task.to_s ]
      end
    end
  end
end
