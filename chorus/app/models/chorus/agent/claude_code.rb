require "json"

module Chorus
  class Agent
    # The Claude Code CLI runtime. Invocation is `claude -p <prompt>` in
    # headless/print mode with NDJSON streaming, run with the workspace as cwd
    # (§4). Drives `claude` through CnfsSupport::Shell.stream: each stdout line is
    # normalized by #parse_event and the non-nil events are yielded to the caller.
    # The concrete model is a column (`model`), passed through as `--model <model>`.
    class ClaudeCode < Agent
      # Tools the agent may use. A constant this phase — see the capability-bag TODO
      # in #build_argv for where this is headed.
      TOOLS = %w[Read Write Edit Bash].freeze

      def skills_agent_key = "claude-code"

      def build_argv(prompt:, resume: nil)
        # TODO(capabilities): `--include-hook-events` is intentionally NOT passed —
        # nothing consumes hook events yet, so passing it only adds noise to the
        # stream. It must not be lost, though: flags should not stay hardcoded per
        # subclass forever. The agent should expose settable *capabilities* (on the
        # record, likely a serialized `settings` bag following the
        # Source/ExternalAccount pattern) that #build_argv derives the argv from.
        # `include_hook_events` is the first such capability; `allowed_tools` the
        # obvious second (a role will want to constrain what its agent may do).
        # Which capabilities are universal across runtimes vs. adapter-specific, and
        # how each maps to a flag per adapter, is deferred.
        [
          "claude", "-p", prompt.to_s,
          "--model", model.to_s,
          "--output-format", "stream-json",
          "--verbose",
          "--include-partial-messages",
          "--allowedTools", TOOLS.join(",")
        ]
      end

      def invoke(prompt:, workspace:, resume: nil, &block)
        argv = build_argv(prompt: prompt, resume: resume)
        CnfsSupport::Shell.stream(*argv, cwd: workspace.pathname) do |line|
          event = parse_event(line)
          block.call(event) if event && block
        end
      end

      # Normalize one NDJSON line. Non-JSON / partial lines are normal, not errors →
      # nil. Unknown event types → nil. session_id is surfaced on the result event
      # (nothing stores it yet, but the session work needs it and it is free here).
      def parse_event(line)
        data = JSON.parse(line)

        case data["type"]
        when "stream_event"
          delta = data.dig("event", "delta")
          return unless delta && delta["type"] == "text_delta"

          { type: :text, text: delta["text"] }
        when "assistant"
          block = Array(data.dig("message", "content")).find { |b| b["type"] == "tool_use" }
          return unless block

          { type: :tool_use, name: block["name"], input: block["input"] }
        when "result"
          {
            type:        :result,
            session_id:  data["session_id"],
            cost_usd:    data["total_cost_usd"],
            duration_ms: data["duration_ms"],
            num_turns:   data["num_turns"],
            usage:       data["usage"],
            is_error:    data["is_error"] || false
          }
        end
      rescue JSON::ParserError
        nil
      end
    end
  end
end
