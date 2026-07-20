module Chorus
  # STI base for an agent's runtime binding. Each subclass is an ADAPTER: it
  # translates "invoke this agent" into one runtime's binary, argv, output format,
  # and skills-agent key — behavior a Concept cannot carry — so the per-runtime
  # variation lives in Rails STI subclasses (ClaudeCode, OpenCode). The Concept
  # still carries CONTENT (system-prompt prose, usage notes) via
  # `has_one_okf :concept`; STI carries INVOCATION BEHAVIOR. The two `type`s stay
  # unconflated: CnfsOkf::Concept#type is an OKF frontmatter field
  # (inheritance_column = nil); AgentAdapter#type is the Rails STI discriminator.
  #
  # The seam is deliberately thin (no Ruby agent framework fits CLI-runtime
  # invocation — §1), modeled on the Source::Git / SkillCatalog shell idiom. It is
  # thin enough that a future API-backed adapter (a single structured RubyLLM call,
  # not a CLI runtime) can slot in beside the CLI subclasses without reshaping it.
  class AgentAdapter < ApplicationRecord
    has_many :agents, dependent: :nullify
    has_one_okf :concept

    validates :name, presence: true
    validates :type, presence: true   # STI: a bare base adapter is not invocable

    # Build (and, when Config#agents_live, run) this runtime's CLI invocation IN the
    # run's `workspace` directory (§4), recording the would-run/did-run argv + cwd
    # into `result` (§8). A subclass fills this in; returns the captured stdout on a
    # successful live run, nil in dry mode or on an operational failure (which is
    # recorded into the Result, not raised — §5).
    def invoke(task:, role:, result:, workspace:)
      raise NotImplementedError, "#{self.class} must implement #invoke"
    end

    # The `npx skills` agent key this runtime installs under (e.g. "claude-code").
    # The single string the shared Chorus::Equipper needs — mounting is
    # runtime-PARAMETERIZED, not runtime-polymorphic (§2).
    def skills_agent_key
      raise NotImplementedError, "#{self.class} must implement #skills_agent_key"
    end

    private

    # Shared invoke body: record the argv (always), then gate the real exec on
    # Config#agents_live (§8). Dry → return nil (recorded, not run). Live → run the
    # runtime and, on success, return its captured stdout. On an OPERATIONAL failure
    # (non-zero exit, timeout, missing binary) the failure is recorded into the
    # durable Result and success flipped to false — NOT raised to the console (§5).
    # Subclasses build their own argv and call this.
    def run_invocation(argv, result, workspace:)
      # Record the argv AND the project path it runs in (pure derivation — no disk in
      # dry mode); the live branch materializes the same directory as the cwd.
      result.record_argv(:invoke, argv, cwd: workspace&.directory)
      return nil unless Chorus::Config.agents_live

      shell = capture_cli(*argv, cwd: workspace.pathname)
      return shell.stdout if shell.success?

      result.add(:invoke, shell.failure_message)
      result.success = false
      nil
    end

    # The shell boundary — now the single CnfsSupport::Shell adapter (array form,
    # no shell, separated stdout/stderr, timeout, non-raising). This is the SOLE
    # swap point if a runtime is ever driven by something other than a subprocess.
    # Returns the normalized Shell::Result; the caller (run_invocation) decides how
    # to treat success vs. failure. The `cnfs_chorus.agent_adapter.invoke` event is
    # preserved by wrapping the adapter call, so the sink is unaffected; the adapter
    # emits its own `cnfs_support.shell.run` span inside.
    def capture_cli(*argv, cwd: nil)
      argv = argv.map(&:to_s)
      instrument(:invoke, cmd: argv.join(" ")) do
        CnfsSupport::Shell.run(*argv, cwd: cwd)
      end
    end

    # Emit AgentAdapter instrumentation under a stable `cnfs_chorus.agent_adapter.*`
    # prefix regardless of STI subclass (mirrors Source pinning its subject).
    def instrument(verb, **payload, &block)
      name = CnfsSupport::Instrumentable.event_name("Chorus::AgentAdapter", verb)
      ActiveSupport::Notifications.instrument(name, **payload, &block)
    end
  end
end
