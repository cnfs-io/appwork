require "rails_helper"

RSpec.describe Appwork::Manager::Goal, type: :model do
  it "has a valid factory" do
    expect(build(:appwork_manager_goal)).to be_valid
  end

  describe "validations" do
    it "requires a name" do
      goal = build(:appwork_manager_goal, name: nil)
      expect(goal).not_to be_valid
      expect(goal.errors[:name]).to be_present
    end

    it "requires a strategy" do
      expect(build(:appwork_manager_goal, strategy: nil)).not_to be_valid
    end
  end

  describe "associations" do
    it { expect(described_class.reflect_on_association(:strategy).macro).to eq(:belongs_to) }
    it { expect(described_class.reflect_on_association(:projects).macro).to eq(:has_many) }
  end

  describe "dependent destruction" do
    it "destroys its projects when destroyed" do
      goal = create(:appwork_manager_goal)
      project = create(:appwork_manager_project, goal: goal)

      goal.destroy

      expect(Appwork::Manager::Project.exists?(project.id)).to be(false)
    end
  end

  describe "Appwork::Chorus::Workable + okf_frontmatter status" do
    it "is a Chorus workable" do
      expect(described_class.include?(Appwork::Chorus::Workable)).to be(true)
    end

    it "has no status column (status lives in the concept)" do
      expect(described_class.column_names).not_to include("status")
    end

    it "can be the subject of a Chorus work order via the polymorphic workable" do
      goal = create(:appwork_manager_goal)
      work_order = chorus_work_order_for(goal)
      expect(goal.reload.work_orders).to contain_exactly(work_order)
    end

    describe "status accessor over the concept" do
      it "reads nil when the concept has no status key" do
        in_concept_root do
          goal = give_concept(create(:appwork_manager_goal))
          expect(goal.status).to be_nil
        end
      end

      it "writes, merges other keys, and persists to disk" do
        in_concept_root do
          goal = give_concept(create(:appwork_manager_goal), frontmatter: "title: X\nowner: rob\n")
          goal.status = "active"
          expect(goal.concept.custom_frontmatter).to eq("owner" => "rob", "status" => "active")
          goal.concept.save!
          expect(goal.reload.status).to eq("active")
        end
      end
    end
  end
end
