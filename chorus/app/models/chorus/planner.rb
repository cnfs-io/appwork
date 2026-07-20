module Chorus
  # The console entry point for the plan flow (plan 010 §5/§8). A PORO, not a model —
  # Invocation is parked, not extended; this is a much smaller thing with one job:
  # an Agent, given a prompt, produces a Plan.
  #
  #   planner = Chorus::Planner.new(agent:, workspace:)
  #   plan    = planner.call(prompt: "...", slug: "user-auth")
  #
  # The flow, in order (§5):
  #   1. Chorus picks the path: doc/plans/<seq>-<slug>.md, relative to the workspace.
  #   2. Chorus constructs a prompt instructing the agent to write to that path.
  #   3. The agent runs with the workspace as cwd, streaming; it writes the file
  #      itself, with its own tools. The stream prints to stdout as it arrives.
  #   4. Chorus verifies the file exists — absence is a recorded failure (raised at
  #      the console this phase; there is no Result to record into).
  #   5. Sync picks the new file up as a Concept.
  #   6. Chorus finds the concept by its bundle-relative path, CLAIMS ownership by
  #      building the Plan with it, and STAMPS `type` through OKF.
  #
  # Chorus never opens the plan file: the agent writes the body, and frontmatter is
  # stamped by setting concept.type and saving (FsConcept#persist_to_disk rebuilds
  # the file, body verbatim). Ownership matters — Sync's owned-concept policy keys on
  # owner_id.present?, so an unowned plan concept would be disk-wins on every sync.
  class Planner
    PLANS_SUBDIR = "plans".freeze

    def initialize(agent:, workspace:)
      @agent     = agent
      @workspace = workspace
    end

    def call(prompt:, slug:)
      adapter = @agent.agent_adapter
      raise ArgumentError, "agent #{@agent.name.inspect} has no agent_adapter" if adapter.nil?

      @workspace.materialize_bundle

      filename      = "#{next_sequence}-#{slug}.md"
      bundle_rel    = File.join(PLANS_SUBDIR, filename)          # "plans/001-user-auth.md"
      workspace_rel = File.join("doc", bundle_rel)              # "doc/plans/001-user-auth.md"
      abs_path      = @workspace.pathname.join(workspace_rel)

      adapter.invoke(prompt: build_prompt(prompt, workspace_rel), workspace: @workspace) do |event|
        next unless event[:type] == :text

        print event[:text]
        $stdout.flush
      end
      puts

      unless abs_path.exist?
        raise "agent did not write the plan file at #{workspace_rel} — nothing to record"
      end

      CnfsOkf::Sync.call(bundle: @workspace.bundle)

      concept = @workspace.bundle.concepts.find_by(path: bundle_rel)
      raise "no concept at #{bundle_rel.inspect} after sync" if concept.nil?

      # Build the Plan WITH the concept so ownership is set (owner_id.present?), then
      # stamp `type` — one disk write, body preserved verbatim.
      plan = Chorus::Plan.create!(workspace: @workspace, agent: @agent, name: slug, concept: concept)
      concept.update!(type: "plan")
      plan
    end

    private

    # The next unused %03d sequence, scanning doc/plans/ for a leading-digits prefix,
    # starting at 001. Single-agent assumption: concurrent planners would collide
    # (deferred, noted in the plan).
    def next_sequence
      dir = @workspace.doc_pathname.join(PLANS_SUBDIR)
      used = dir.exist? ? dir.children.filter_map { |c| c.basename.to_s[/\A(\d+)/, 1]&.to_i } : []
      format("%03d", (used.max || 0) + 1)
    end

    # Instruct the agent to write its plan to the exact relative path (cwd is the
    # workspace). Frontmatter is NOT requested — Chorus stamps `type` through OKF.
    def build_prompt(user_prompt, workspace_rel)
      <<~PROMPT.strip
        #{user_prompt}

        Write your plan as a markdown document to this exact path, relative to the
        current directory: #{workspace_rel}

        Create any directories that do not yet exist. Write the markdown body only —
        do not add a YAML frontmatter block; that is added for you.
      PROMPT
    end
  end
end
