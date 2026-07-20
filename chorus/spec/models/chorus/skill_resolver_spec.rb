require "rails_helper"

# Chorus::SkillResolver — STUBBED in 007 (§4): maps a role's name-only requirements
# to as-if-resolved sources. Real catalog resolution + curation policy lands here
# later; for now it echoes each requirement against the default repo.
RSpec.describe Chorus::SkillResolver do
  it "resolves each requirement to an installable (resource, skill) source" do
    role = create(:chorus_agent_role, :with_requirements)

    resolved = described_class.new(role).resolve

    expect(resolved.map(&:name)).to contain_exactly("web-design-guidelines", "frontend-design")
    expect(resolved.map(&:resource).uniq).to eq([ Chorus::SkillResolver::STUB_RESOURCE ])
    expect(resolved.map(&:skill)).to contain_exactly("web-design-guidelines", "frontend-design")
  end

  it "returns nothing for a role with no requirements" do
    role = create(:chorus_agent_role)
    expect(described_class.new(role).resolve).to eq([])
  end
end
