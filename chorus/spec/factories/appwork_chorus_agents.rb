FactoryBot.define do
  # Agent is an STI base on its runtime (plan 011 §2). A bare base Agent is not
  # invocable (validates :type), so build a concrete runtime. ClaudeCode is the
  # default; OpenCode is available for the STI/streaming-contract specs.
  factory :appwork_chorus_agent, class: "Appwork::Chorus::Agent::ClaudeCode" do
    name { "Agent #{rand(1000)}" }
    model { "opus-4.8" }
  end

  factory :appwork_chorus_agent_open_code, class: "Appwork::Chorus::Agent::OpenCode" do
    name { "OpenCode #{rand(1000)}" }
    model { "nemotron" }
  end
end
