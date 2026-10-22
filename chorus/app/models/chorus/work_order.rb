module Chorus
  # A job against a site (plan 011 §4). A feature request that lands against a
  # Workspace, carrying the Role required to execute it; an Agent is hired to fill
  # that role. #execute! reads the request and produces a Plan document plus a Result.
  #
  # A WorkOrder is a DOCUMENT: in practice Claude Desktop writes it — a summary of a
  # design conversation, landing as markdown in the workspace's viewport — and the
  # row is created pointing at it. That is why it carries a concept (has_one_okf
  # :concept) rather than a text column.
  #
  # The role attaches to the WORK, not the worker (§1): `role` is what's needed to
  # EXECUTE this order. Its Plans each carry their OWN role (whom the architect
  # addresses the plan to), distinct from this one — delegation, not denormalization.
  #
  # Everything the host decides arrives fully specified (§5): a work order names its
  # workable, workspace, role, and (optionally) agent, or it is invalid. Chorus
  # builds no triage, hiring, or defaulting this phase.
  class WorkOrder < ApplicationRecord
    PLANS_SUBDIR = "plans".freeze

    belongs_to :workable, polymorphic: true
    belongs_to :workspace
    belongs_to :role
    belongs_to :agent, optional: true

    has_one_okf :concept                             # the request itself, as markdown

    has_many :plans, dependent: :destroy
    has_many :results, as: :resultable, dependent: :destroy

    # Execute this work order (plan 011 §10, absorbing 010's Chorus::Planner — the
    # logic moved, not rewritten). The hired agent reads the request and writes a
    # Plan document into the workspace's viewport; Chorus discovers the synced
    # Concept, CLAIMS it by building the Plan with it (ownership matters — Sync's
    # owned-concept policy keys on owner_id.present?, so an unowned plan concept would
    # be disk-wins on every sync), stamps `type = "plan"` through OKF, and records the
    # invocation as a Result.
    #
    # `plan_role` is WHO SHOULD EXECUTE the produced plan (an architect addresses it
    # to the SWE), distinct from this order's own role.
    #
    # The flow, in order:
    #   1. Chorus picks the plan path — plans/<seq>-<slug>.md relative to the VIEWPORT.
    #   2. Chorus constructs a prompt instructing the agent to write to that path
    #      (expressed relative to the agent's cwd, the workspace directory).
    #   3. The agent runs with the workspace as cwd, streaming; it writes the file
    #      itself. `external_session_id` is latched from the first event that carries
    #      one and written back immediately, so an interrupt mid-first-turn still
    #      leaves a resumable order.
    #   4. Chorus verifies the file exists — absence is a RECORDED failure (a Result
    #      with success: false) plus a raise.
    #   5. Sync reconciles the bundle; Chorus finds the concept by its bundle-relative
    #      path (which carries the viewport's own path as a prefix — NOT a bare
    #      "plans/..."), builds the Plan claiming ownership, and stamps `type`.
    #   6. Chorus persists a Result for the invocation.
    def execute!(slug:, plan_role:)
      viewport = workspace.view_port
      raise ArgumentError, "workspace #{workspace.id} has no view_port" if viewport.nil?

      bundle   = viewport.bundle
      filename = "#{next_sequence(viewport)}-#{slug}.md"
      abs_path = viewport.pathname.join(PLANS_SUBDIR, filename)

      # Two derived paths, both computed from the absolute path so neither assumes a
      # bare "plans/..." (concept paths carry the viewport's path within the bundle
      # as a prefix, §7):
      #   agent_rel  — relative to the agent's cwd (the workspace dir), for the prompt
      #   bundle_rel — the concept's key after sync (relative to the bundle root)
      agent_rel  = abs_path.relative_path_from(workspace.pathname).to_s
      bundle_rel = abs_path.relative_path_from(bundle.pathname).to_s

      prompt = build_prompt(agent_rel)
      argv   = agent.build_argv(prompt: prompt)
      run    = stream_agent(prompt)

      unless abs_path.exist?
        record_result(argv:, success: false, is_error: true,
                      messages: { "error" => [ "agent did not write the plan file at #{agent_rel}" ] })
        raise "agent did not write the plan file at #{agent_rel} — recorded a failed Result"
      end

      CnfsOkf::Sync.call(bundle: bundle)
      concept = bundle.concepts.find_by(path: bundle_rel)
      raise "no concept at #{bundle_rel.inspect} after sync" if concept.nil?

      # Build the Plan WITH the concept so ownership is set, then stamp `type` — one
      # disk write, body preserved verbatim.
      plan = plans.create!(role: plan_role, agent: agent, name: slug, concept: concept)
      concept.update!(type: "plan")

      record_result(argv:, success: !run[:is_error], is_error: run[:is_error] || false,
                    external_session_id: run[:session_id], cost_usd: run[:cost_usd],
                    duration_ms: run[:duration_ms], num_turns: run[:num_turns], usage: run[:usage])
      plan
    end

    private

    # Drive the agent, printing text deltas as they arrive and latching the session id
    # the moment the first event carries one (§4). Returns the terminal :result event
    # payload (empty hash if none arrived).
    def stream_agent(prompt)
      run = {}
      agent.invoke(prompt: prompt, workspace: workspace) do |event|
        latch_session(event[:session_id]) if event[:session_id] && external_session_id.nil?

        case event[:type]
        when :text
          print event[:text]
          $stdout.flush
        when :result
          run = event
        end
      end
      puts
      run
    end

    # Write the runtime session id back immediately, before the run finishes, so an
    # interrupt mid-first-turn still leaves a resumable order (§4). update_column: a
    # bare write with no validation/callback, mid-stream.
    def latch_session(sid)
      update_column(:external_session_id, sid)
    end

    def record_result(**attrs)
      results.create!(cwd: workspace.pathname.to_s, **attrs)
    end

    # The next unused %03d sequence, scanning the viewport's plans/ for a
    # leading-digits prefix, starting at 001. Single-agent assumption: concurrent
    # planners would collide (deferred, noted in the plan).
    def next_sequence(viewport)
      dir = viewport.pathname.join(PLANS_SUBDIR)
      used = dir.exist? ? dir.children.filter_map { |c| c.basename.to_s[/\A(\d+)/, 1]&.to_i } : []
      format("%03d", (used.max || 0) + 1)
    end

    # Instruct the agent to write its plan to the exact path (relative to its cwd, the
    # workspace). The request is the work order's own concept body, if any.
    # Frontmatter is NOT requested — Chorus stamps `type` through OKF.
    def build_prompt(plan_rel)
      request = concept&.content.to_s.strip
      <<~PROMPT.strip
        #{request}

        Write your plan as a markdown document to this exact path, relative to the
        current directory: #{plan_rel}

        Create any directories that do not yet exist. Write the markdown body only —
        do not add a YAML frontmatter block; that is added for you.
      PROMPT
    end
  end
end
