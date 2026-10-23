module Appwork
  module Chorus
    class Agent
      # The OpenCode CLI runtime. Registered by its `skills_agent_key`; its streaming
      # adapter (build_argv/invoke/parse_event on `opencode run`, with opencode's own
      # stream format) is not built this phase — plan 010 rebuilt only ClaudeCode on
      # Shell.stream, so those inherit the base NotImplementedError until opencode
      # earns its own streaming path.
      class OpenCode < Agent
        def skills_agent_key = "opencode"
      end
    end
  end
end
