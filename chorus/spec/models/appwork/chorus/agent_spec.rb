require "rails_helper"

# Chorus::Agent — an STI base on its RUNTIME (plan 011 §2). The former AgentAdapter
# collapsed in: every agent is a distinct (runtime, model) pairing carrying its own
# `model`, so the join bought nothing. Runtime is the STI discriminator; the concrete
# subclasses (ClaudeCode, OpenCode) carry the invocation behavior a Concept cannot.
RSpec.describe Chorus::Agent, type: :model do
  describe "the STI base" do
    it "has a valid concrete factory" do
      expect(build(:chorus_agent)).to be_valid
    end

    it "cannot be persisted without a concrete type" do
      base = Chorus::Agent.new(name: "bare")
      expect(base).not_to be_valid
      expect(base.errors[:type]).to be_present
    end

    it "requires a name" do
      agent = build(:chorus_agent, name: nil)
      expect(agent).not_to be_valid
      expect(agent.errors[:name]).to be_present
    end

    it "leaves the four-method contract unimplemented on the base" do
      base = Chorus::Agent.new
      expect { base.build_argv(prompt: "p") }.to raise_error(NotImplementedError)
      expect { base.invoke(prompt: "p", workspace: nil) }.to raise_error(NotImplementedError)
      expect { base.parse_event("{}") }.to raise_error(NotImplementedError)
      expect { base.skills_agent_key }.to raise_error(NotImplementedError)
    end

    it "owns its content through has_one_okf :concept" do
      expect(described_class.reflect_on_association(:concept).macro).to eq(:has_one)
    end

    it "resolves the concrete class from the type column" do
      agent = create(:chorus_agent)
      expect(Chorus::Agent.find(agent.id)).to be_a(Chorus::Agent::ClaudeCode)
    end

    # The role attaches to the WORK, not the worker (plan 011 §1): Agent carries no
    # Role and no adapter FK (it IS its adapter now).
    it "does not couple to role" do
      expect(described_class.reflect_on_association(:role)).to be_nil
    end

    it "no longer carries a separate agent_adapter binding (collapsed into STI)" do
      expect(described_class.reflect_on_association(:agent_adapter)).to be_nil
      expect(described_class.column_names).not_to include("agent_adapter_id")
    end

    it "does not enumerate issues/tickets from the Chorus side" do
      expect(described_class.reflect_on_association(:issues)).to be_nil
      expect(described_class.reflect_on_association(:tickets)).to be_nil
    end
  end

  describe Chorus::Agent::ClaudeCode do
    subject(:agent) { create(:chorus_agent, model: "opus-4.8") }

    it "declares its skills_agent_key" do
      expect(agent.skills_agent_key).to eq("claude-code")
    end

    describe "#build_argv (the tested surface)" do
      it "builds the exact headless streaming argv, including --model from the column" do
        expect(agent.build_argv(prompt: "Build a table")).to eq([
          "claude", "-p", "Build a table",
          "--model", "opus-4.8",
          "--output-format", "stream-json",
          "--verbose",
          "--include-partial-messages",
          "--allowedTools", "Read,Write,Edit,Bash"
        ])
      end

      it "reflects the agent's own model" do
        sonnet = create(:chorus_agent, model: "sonnet-4.6")
        expect(sonnet.build_argv(prompt: "x")).to include("--model", "sonnet-4.6")
      end

      it "does not pass --include-hook-events this phase" do
        expect(agent.build_argv(prompt: "x")).not_to include("--include-hook-events")
      end

      it "ignores resume this phase (argv is identical with or without it)" do
        expect(agent.build_argv(prompt: "x", resume: "sess-1")).to eq(agent.build_argv(prompt: "x"))
      end
    end

    describe "#parse_event (against captured NDJSON fixture lines)" do
      let(:lines) do
        path = File.expand_path("../../fixtures/claude_code/stream.ndjson", __dir__)
        File.readlines(path, chomp: true)
      end

      it "normalizes a text_delta stream_event to a :text event" do
        expect(agent.parse_event(lines[1])).to eq({ type: :text, text: "Hello, world" })
      end

      it "returns nil for a non-text delta (e.g. input_json_delta)" do
        expect(agent.parse_event(lines[2])).to be_nil
      end

      it "normalizes an assistant tool_use block to a :tool_use event" do
        expect(agent.parse_event(lines[3])).to eq({
          type: :tool_use, name: "Write",
          input: { "file_path" => "doc/plans/001-x.md", "content" => "# Plan" }
        })
      end

      it "returns nil for an assistant message carrying no tool_use" do
        expect(agent.parse_event(lines[4])).to be_nil
      end

      it "normalizes a result event, surfacing session_id" do
        expect(agent.parse_event(lines[5])).to eq({
          type:        :result,
          session_id:  "sess-abc",
          cost_usd:    0.0123,
          duration_ms: 4567,
          num_turns:   3,
          usage:       { "input_tokens" => 100, "output_tokens" => 200 },
          is_error:    false
        })
      end

      it "returns nil for an unknown event type (system init)" do
        expect(agent.parse_event(lines[0])).to be_nil
      end

      it "returns nil for malformed JSON (a partial line is normal, not an error)" do
        expect(agent.parse_event('{"type":"resu')).to be_nil
      end

      it "returns nil for a non-JSON line" do
        expect(agent.parse_event("not json at all")).to be_nil
      end
    end
  end

  describe Chorus::Agent::OpenCode do
    subject(:agent) { create(:chorus_agent_open_code) }

    it "declares its skills_agent_key" do
      expect(agent.skills_agent_key).to eq("opencode")
    end

    # Its streaming adapter is not built this phase (010 rebuilt only ClaudeCode).
    it "leaves the streaming contract unimplemented" do
      expect { agent.build_argv(prompt: "x") }.to raise_error(NotImplementedError)
      expect { agent.parse_event("{}") }.to raise_error(NotImplementedError)
    end
  end
end
