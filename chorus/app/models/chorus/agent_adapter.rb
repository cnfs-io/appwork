module Chorus
  # STI base for an agent's runtime binding. Each subclass is an ADAPTER: it
  # translates "invoke this agent" into one runtime's binary, argv, stream format,
  # and skills-agent key — behavior a Concept cannot carry — so the per-runtime
  # variation lives in Rails STI subclasses (ClaudeCode, ...). The Concept still
  # carries CONTENT (system-prompt prose, usage notes) via `has_one_okf :concept`;
  # STI carries INVOCATION BEHAVIOR. The two `type`s stay unconflated:
  # CnfsOkf::Concept#type is an OKF frontmatter field (inheritance_column = nil);
  # AgentAdapter#type is the Rails STI discriminator.
  #
  # THE HARNESS INVARIANT (plan 010): Chorus does not modify agent behavior. It
  # prepares the environment (workspace as cwd, prompt constructed), invokes the
  # agent's native CLI, observes the stream, and records what happened. Anything
  # requiring the agent to behave differently than it would standing alone is out of
  # scope — which is why the agent writes its own files and Chorus only observes.
  #
  # The four-method contract (§7), each runtime-specific and unimplemented here:
  #   - build_argv    — the CLI argv for a prompt
  #   - invoke        — run the CLI in the workspace, streaming normalized events
  #   - parse_event   — normalize one raw stdout line into a Hash (or nil)
  #   - skills_agent_key — the `npx skills` agent key this runtime installs under
  class AgentAdapter < ApplicationRecord
    has_many :agents, dependent: :nullify
    has_one_okf :concept

    validates :name, presence: true
    validates :type, presence: true   # STI: a bare base adapter is not invocable

    # Build the argv for a prompt. `resume:` is accepted and IGNORED this phase — the
    # parameter exists so the session work can fill it in without reshaping every
    # caller.
    def build_argv(prompt:, resume: nil)
      raise NotImplementedError, "#{self.class} must implement #build_argv"
    end

    # Run the CLI in `workspace.pathname`, streaming. Yields normalized events to the
    # block as they arrive. Returns the CnfsSupport::Shell::Result.
    def invoke(prompt:, workspace:, resume: nil, &block)
      raise NotImplementedError, "#{self.class} must implement #invoke"
    end

    # Normalize one raw stdout line into a Hash, or nil if it carries nothing
    # interesting. THE runtime-specific seam — each CLI has its own stream format.
    def parse_event(line)
      raise NotImplementedError, "#{self.class} must implement #parse_event"
    end

    # The `npx skills` agent key this runtime installs under (e.g. "claude-code").
    def skills_agent_key
      raise NotImplementedError, "#{self.class} must implement #skills_agent_key"
    end
  end
end
