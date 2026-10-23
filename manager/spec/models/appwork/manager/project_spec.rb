require "rails_helper"

RSpec.describe Appwork::Manager::Project, type: :model do
  it "has a valid factory" do
    expect(build(:appwork_manager_project)).to be_valid
  end

  describe "validations" do
    it "requires a name" do
      project = build(:appwork_manager_project, name: nil)
      expect(project).not_to be_valid
      expect(project.errors[:name]).to be_present
    end

    it "requires a goal" do
      expect(build(:appwork_manager_project, goal: nil)).not_to be_valid
    end
  end

  describe "associations" do
    it { expect(described_class.reflect_on_association(:goal).macro).to eq(:belongs_to) }
    it { expect(described_class.reflect_on_association(:tickets).macro).to eq(:has_many) }

    it "reaches strategy through goal" do
      reflection = described_class.reflect_on_association(:strategy)
      expect(reflection.macro).to eq(:has_one)
      expect(reflection.options[:through]).to eq(:goal)
    end

    it "returns the strategy up the intent spine" do
      strategy = create(:appwork_manager_strategy)
      goal = create(:appwork_manager_goal, strategy: strategy)
      project = create(:appwork_manager_project, goal: goal)
      expect(project.strategy).to eq(strategy)
    end

    # The work-order inverse is supplied by Appwork::Chorus::Workable (not hand-declared
    # on Project) — it must exist exactly once, as the polymorphic `as: :workable`.
    it "exposes its work orders via the polymorphic workable inverse (from the concern)" do
      reflection = described_class.reflect_on_association(:work_orders)
      expect(reflection.macro).to eq(:has_many)
      expect(reflection.options[:as]).to eq(:workable)
    end
  end

  describe "Appwork::Chorus::Workable + okf_frontmatter status" do
    it "is a Chorus workable" do
      expect(described_class.include?(Appwork::Chorus::Workable)).to be(true)
    end

    it "carries an OKF concept" do
      expect(described_class.reflect_on_association(:concept).options[:class_name])
        .to eq("Appwork::Okf::Concept")
    end

    it "has no status column (status lives in the concept)" do
      expect(described_class.column_names).not_to include("status")
    end

    describe "status accessor over the concept" do
      it "reads nil when the concept has no status key" do
        in_concept_root do
          project = give_concept(create(:appwork_manager_project))
          expect(project.status).to be_nil
        end
      end

      it "writes, merges other keys, and persists to disk" do
        in_concept_root do
          project = give_concept(create(:appwork_manager_project), frontmatter: "title: X\nowner: rob\n")
          project.status = "in_progress"
          expect(project.concept.custom_frontmatter).to eq("owner" => "rob", "status" => "in_progress")
          project.concept.save!
          expect(project.reload.status).to eq("in_progress")
        end
      end
    end
  end

  # A Chorus work order names a project as its subject through its polymorphic
  # `workable`. Exercises the allowed org → chorus cross-gem seam end-to-end.
  describe "Chorus work orders (the subject seam)" do
    it "is the subject of the work orders whose workable points at it" do
      project = create(:appwork_manager_project)
      work_order = chorus_work_order_for(project)
      expect(project.reload.work_orders).to contain_exactly(work_order)
    end

    it "nullifies its work orders' workable when destroyed, leaving them in place" do
      project = create(:appwork_manager_project)
      work_order = chorus_work_order_for(project)

      project.destroy

      expect(work_order.reload.workable_id).to be_nil
      expect(Appwork::Chorus::WorkOrder.exists?(work_order.id)).to be(true)
    end
  end

  describe "dependent destruction" do
    it "destroys its tickets when destroyed" do
      project = create(:appwork_manager_project)
      ticket = create(:appwork_manager_ticket, project: project)

      project.destroy

      expect(Appwork::Manager::Ticket.exists?(ticket.id)).to be(false)
    end
  end
end
