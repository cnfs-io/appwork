require "rails_helper"

RSpec.describe MicroManager::Strategy, type: :model do
  it "has a valid factory" do
    expect(build(:micro_manager_strategy)).to be_valid
  end

  describe "validations" do
    it "requires a name" do
      strategy = build(:micro_manager_strategy, name: nil)
      expect(strategy).not_to be_valid
      expect(strategy.errors[:name]).to be_present
    end
  end

  describe "associations" do
    it { expect(described_class.reflect_on_association(:goals).macro).to eq(:has_many) }
  end

  describe "dependent destruction" do
    it "destroys its goals when destroyed" do
      strategy = create(:micro_manager_strategy)
      goal = create(:micro_manager_goal, strategy: strategy)

      strategy.destroy

      expect(MicroManager::Goal.exists?(goal.id)).to be(false)
    end
  end

  # Decomposition is work: a Strategy is occupied (to derive goals) exactly as a
  # Ticket is occupied (to execute). So Strategy is a Workable, and carries an
  # opaque status via okf_frontmatter — independently of occupiability.
  describe "Chorus::Workable + okf_frontmatter status" do
    it "is a Chorus workable" do
      expect(described_class.include?(Chorus::Workable)).to be(true)
    end

    it "has no status column (status lives in the concept)" do
      expect(described_class.column_names).not_to include("status")
    end

    it "can be occupied by a Chorus workspace via the polymorphic workable" do
      strategy = create(:micro_manager_strategy)
      workspace = Chorus::Workspace.create!(name: "Planning", workable: strategy)
      expect(strategy.reload.workspace).to eq(workspace)
    end

    describe "status accessor over the concept" do
      it "reads nil when the concept has no status key" do
        in_concept_root do
          strategy = give_concept(create(:micro_manager_strategy))
          expect(strategy.status).to be_nil
        end
      end

      it "writes, merges other keys, and persists to disk" do
        in_concept_root do
          strategy = give_concept(create(:micro_manager_strategy), frontmatter: "title: X\nowner: rob\n")
          strategy.status = "active"
          expect(strategy.concept.custom_frontmatter).to eq("owner" => "rob", "status" => "active")
          strategy.concept.save!
          expect(strategy.reload.status).to eq("active")
        end
      end
    end
  end
end
