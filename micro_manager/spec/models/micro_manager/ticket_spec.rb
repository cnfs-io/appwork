require "rails_helper"

RSpec.describe MicroManager::Ticket, type: :model do
  it "has a valid factory" do
    expect(build(:micro_manager_ticket)).to be_valid
  end

  describe "validations" do
    it "requires a title" do
      ticket = build(:micro_manager_ticket, title: nil)
      expect(ticket).not_to be_valid
      expect(ticket.errors[:title]).to be_present
    end

    it "requires a project" do
      expect(build(:micro_manager_ticket, project: nil)).not_to be_valid
    end

    it "is valid without an agent (agent is optional)" do
      expect(build(:micro_manager_ticket, agent: nil)).to be_valid
    end
  end

  describe "associations" do
    it { expect(described_class.reflect_on_association(:project).macro).to eq(:belongs_to) }

    it "marks agent as optional" do
      expect(described_class.reflect_on_association(:agent).options[:optional]).to be(true)
    end

    it "points agent at a Chorus agent (the allowed org → chorus direction)" do
      expect(described_class.reflect_on_association(:agent).options[:class_name]).to eq("Chorus::Agent")
    end
  end

  # The assignee backlink is a real, colocated-DB FK to chorus_agents.
  describe "assignment to a Chorus agent" do
    it "can be assigned to a chorus agent" do
      agent = Chorus::Agent.create!(name: "Echo")
      ticket = create(:micro_manager_ticket, agent: agent)
      expect(ticket.reload.agent).to eq(agent)
    end
  end

  describe "traversal up the intent spine" do
    it "reaches the strategy through project → goal" do
      strategy = create(:micro_manager_strategy)
      goal = create(:micro_manager_goal, strategy: strategy)
      project = create(:micro_manager_project, goal: goal)
      ticket = create(:micro_manager_ticket, project: project)

      expect(ticket.project.goal.strategy).to eq(strategy)
    end
  end

  describe "Chorus::Workable + okf_frontmatter status" do
    it "is a Chorus workable" do
      expect(described_class.include?(Chorus::Workable)).to be(true)
    end

    it "carries an OKF concept" do
      expect(described_class.reflect_on_association(:concept).options[:class_name])
        .to eq("CnfsOkf::Concept")
    end

    it "has no status column (status lives in the concept)" do
      expect(described_class.column_names).not_to include("status")
    end

    it "can be occupied by a Chorus workspace via the polymorphic workable" do
      ticket = create(:micro_manager_ticket)
      workspace = Chorus::Workspace.create!(name: "Review", workable: ticket)
      expect(ticket.reload.workspace).to eq(workspace)
    end

    describe "status accessor over the concept" do
      it "reads nil when the concept has no status key" do
        in_concept_root do
          ticket = give_concept(create(:micro_manager_ticket))
          expect(ticket.status).to be_nil
        end
      end

      it "writes, merges other keys, and persists to disk" do
        in_concept_root do
          ticket = give_concept(create(:micro_manager_ticket), frontmatter: "title: X\nowner: rob\n")
          ticket.status = "blocked"
          expect(ticket.concept.custom_frontmatter).to eq("owner" => "rob", "status" => "blocked")
          ticket.concept.save!
          expect(ticket.reload.status).to eq("blocked")
        end
      end
    end
  end
end
