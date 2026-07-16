FactoryBot.define do
  # Base AgentProfile is abstract in practice (validates :type present); build
  # concrete runtimes via the subclass factories below.
  factory :chorus_agent_profile_claude_code, class: "Chorus::AgentProfile::ClaudeCode" do
    name { "Claude Code #{rand(1000)}" }
  end

  factory :chorus_agent_profile_open_code, class: "Chorus::AgentProfile::OpenCode" do
    name { "OpenCode #{rand(1000)}" }
  end
end
