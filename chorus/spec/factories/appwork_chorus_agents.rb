FactoryBot.define do
  # Agent is an STI base on its runtime (plan 011 §2). A bare base Agent is not
  # invocable (validates :type), so build a concrete runtime. ClaudeCode is the
  # default; OpenCode is available for the STI/streaming-contract specs.
  factory :chorus_agent, class: "Chorus::Agent::ClaudeCode" do
    name { "Agent #{rand(1000)}" }
    model { "opus-4.8" }
  end

  factory :chorus_agent_open_code, class: "Chorus::Agent::OpenCode" do
    name { "OpenCode #{rand(1000)}" }
    model { "nemotron" }
  end
end
