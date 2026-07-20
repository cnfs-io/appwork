FactoryBot.define do
  # Base AgentAdapter is abstract in practice (validates :type present); build
  # concrete runtimes via the subclass factories below.
  factory :chorus_agent_adapter_claude_code, class: "Chorus::AgentAdapter::ClaudeCode" do
    name { "Claude Code #{rand(1000)}" }
  end

  factory :chorus_agent_adapter_open_code, class: "Chorus::AgentAdapter::OpenCode" do
    name { "OpenCode #{rand(1000)}" }
  end
end
