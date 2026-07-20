module Chorus
  class AgentAdapter
    # The OpenCode CLI runtime. Registered by its `skills_agent_key`; its streaming
    # adapter (build_argv/invoke/parse_event on `opencode run`, with opencode's own
    # stream format) is not built this phase — plan 010 rebuilds only ClaudeCode on
    # Shell.stream, so those inherit the base NotImplementedError until opencode
    # earns its own streaming path.
    class OpenCode < AgentAdapter
      def skills_agent_key = "opencode"
    end
  end
end
