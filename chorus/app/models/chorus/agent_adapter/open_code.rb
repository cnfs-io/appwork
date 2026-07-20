module Chorus
  class AgentAdapter
    # The OpenCode CLI runtime. Proven identically to ClaudeCode — subclass,
    # `skills_agent_key`, argv construction, all unit-tested in dry mode; never run
    # live in the suite. Skills mount under the "opencode" agent key; invocation is
    # `opencode run <task>` (non-interactive run).
    class OpenCode < AgentAdapter
      def skills_agent_key = "opencode"

      def invoke(task:, role:, result:, workspace:)
        run_invocation(invocation_argv(task), result, workspace: workspace)
      end

      private

      def invocation_argv(task)
        [ "opencode", "run", task.to_s ]
      end
    end
  end
end
