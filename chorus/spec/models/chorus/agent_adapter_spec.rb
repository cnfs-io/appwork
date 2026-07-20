require "rails_helper"

RSpec.describe Chorus::AgentAdapter, type: :model do
  describe "the STI base" do
    it "cannot be persisted without a concrete type" do
      base = Chorus::AgentAdapter.new(name: "bare")
      expect(base).not_to be_valid
      expect(base.errors[:type]).to be_present
    end

    it "requires a name" do
      adapter = build(:chorus_agent_adapter_claude_code, name: nil)
      expect(adapter).not_to be_valid
      expect(adapter.errors[:name]).to be_present
    end

    it "leaves the four-method contract unimplemented" do
      base = Chorus::AgentAdapter.new
      expect { base.build_argv(prompt: "p") }.to raise_error(NotImplementedError)
      expect { base.invoke(prompt: "p", workspace: nil) }.to raise_error(NotImplementedError)
      expect { base.parse_event("{}") }.to raise_error(NotImplementedError)
      expect { base.skills_agent_key }.to raise_error(NotImplementedError)
    end

    it "keeps its associations (agents, concept)" do
      expect(described_class.reflect_on_association(:agents).macro).to eq(:has_many)
      expect(described_class.reflect_on_association(:concept).macro).to eq(:has_one)
    end

    it "resolves the concrete class from the type column" do
      adapter = create(:chorus_agent_adapter_claude_code)
      expect(Chorus::AgentAdapter.find(adapter.id)).to be_a(Chorus::AgentAdapter::ClaudeCode)
    end
  end

  describe Chorus::AgentAdapter::ClaudeCode do
    subject(:adapter) { create(:chorus_agent_adapter_claude_code) }

    it "declares its skills_agent_key" do
      expect(adapter.skills_agent_key).to eq("claude-code")
    end

    describe "#build_argv (the tested surface)" do
      it "builds the exact headless streaming argv" do
        expect(adapter.build_argv(prompt: "Build a table")).to eq([
          "claude", "-p", "Build a table",
          "--output-format", "stream-json",
          "--verbose",
          "--include-partial-messages",
          "--allowedTools", "Read,Write,Edit,Bash"
        ])
      end

      it "does not pass --include-hook-events this phase" do
        expect(adapter.build_argv(prompt: "x")).not_to include("--include-hook-events")
      end

      it "ignores resume this phase (argv is identical with or without it)" do
        expect(adapter.build_argv(prompt: "x", resume: "sess-1")).to eq(adapter.build_argv(prompt: "x"))
      end
    end

    describe "#parse_event (against captured NDJSON fixture lines)" do
      let(:lines) do
        path = File.expand_path("../../fixtures/claude_code/stream.ndjson", __dir__)
        File.readlines(path, chomp: true)
      end

      it "normalizes a text_delta stream_event to a :text event" do
        expect(adapter.parse_event(lines[1])).to eq({ type: :text, text: "Hello, world" })
      end

      it "returns nil for a non-text delta (e.g. input_json_delta)" do
        expect(adapter.parse_event(lines[2])).to be_nil
      end

      it "normalizes an assistant tool_use block to a :tool_use event" do
        expect(adapter.parse_event(lines[3])).to eq({
          type: :tool_use, name: "Write",
          input: { "file_path" => "doc/plans/001-x.md", "content" => "# Plan" }
        })
      end

      it "returns nil for an assistant message carrying no tool_use" do
        expect(adapter.parse_event(lines[4])).to be_nil
      end

      it "normalizes a result event, surfacing session_id" do
        expect(adapter.parse_event(lines[5])).to eq({
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
        expect(adapter.parse_event(lines[0])).to be_nil
      end

      it "returns nil for malformed JSON (a partial line is normal, not an error)" do
        expect(adapter.parse_event('{"type":"resu')).to be_nil
      end

      it "returns nil for a non-JSON line" do
        expect(adapter.parse_event("not json at all")).to be_nil
      end
    end
  end

  describe Chorus::AgentAdapter::OpenCode do
    subject(:adapter) { create(:chorus_agent_adapter_open_code) }

    it "declares its skills_agent_key" do
      expect(adapter.skills_agent_key).to eq("opencode")
    end

    # Its streaming adapter is not built this phase (010 rebuilds only ClaudeCode).
    it "leaves the streaming contract unimplemented" do
      expect { adapter.build_argv(prompt: "x") }.to raise_error(NotImplementedError)
      expect { adapter.parse_event("{}") }.to raise_error(NotImplementedError)
    end
  end
end
