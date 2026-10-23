module Appwork
  module Chorus
    # A participant's runtime binding — an STI base on the RUNTIME (plan 011 §2). The
    # former AgentAdapter collapsed into Agent: with `model` on the row every agent is
    # a distinct (runtime, model) pairing and there is nothing left to share, so the
    # join bought nothing and cost a hop to reach #build_argv. Runtime is the primary
    # axis of variation, so it is the STI discriminator — Appwork::Chorus::Agent::ClaudeCode
    # reads as "this agent IS a Claude Code agent." Agent carries NO workspace FK
    # (agent↔workspace is discovered host-side) and NO Role (the role attaches to the
    # WORK, not the worker — plan 011 §1).
    #
    # Each subclass is an ADAPTER: it translates "invoke this agent" into one runtime's
    # binary, argv, stream format, and skills-agent key — behavior a Concept cannot
    # carry. The Concept still carries CONTENT (system-prompt prose, usage notes) via
    # `has_one_okf :concept`; STI carries INVOCATION BEHAVIOR. The two `type`s stay
    # unconflated: Appwork::Okf::Concept#type is an OKF frontmatter field
    # (inheritance_column = nil); Agent#type is the Rails STI discriminator.
    #
    # THE HARNESS INVARIANT (plan 010): Chorus does not modify agent behavior. It
    # prepares the environment (workspace as cwd, prompt constructed), invokes the
    # agent's native CLI, observes the stream, and records what happened. Anything
    # requiring the agent to behave differently than it would standing alone is out of
    # scope — which is why the agent writes its own files and Chorus only observes.
    #
    # Agent is deliberately thin right now (plan 011 §2): with costing deferred it is
    # close to a lookup table of runtime+model combinations. That is a known, accepted
    # state — budgets are what make it a real entity (a seat with a wallet). Do not add
    # speculative columns to fatten it.
    #
    # The four-method contract (§7), each runtime-specific and unimplemented here:
    #   - build_argv    — the CLI argv for a prompt
    #   - invoke        — run the CLI in the workspace, streaming normalized events
    #   - parse_event   — normalize one raw stdout line into a Hash (or nil)
    #   - skills_agent_key — the `npx skills` agent key this runtime installs under
    class Agent < ApplicationRecord
      has_one_okf :concept

      validates :name, presence: true
      validates :type, presence: true   # STI: a bare base agent is not invocable

      # Build the argv for a prompt. `resume:` is accepted and IGNORED this phase — the
      # parameter exists so the session work can fill it in without reshaping every
      # caller.
      def build_argv(prompt:, resume: nil)
        raise NotImplementedError, "#{self.class} must implement #build_argv"
      end

      # Run the CLI in `workspace.pathname`, streaming. Yields normalized events to the
      # block as they arrive. Returns the Partitia::Support::Shell::Result.
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
end
