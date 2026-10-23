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

    # The workspace inverse is now supplied by Appwork::Chorus::Workable (not hand-declared
    # on Project) — it must exist exactly once, as the polymorphic `as: :workable`.
    it "exposes its workspace via the polymorphic workable inverse (from the concern)" do
      reflection = described_class.reflect_on_association(:workspace)
      expect(reflection.macro).to eq(:has_one)
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

  # A Chorus workspace occupies a project by pointing its polymorphic `workable`
  # at it. Exercises the allowed org → chorus cross-gem seam end-to-end.
  describe "hosting workspace (the active slot)" do
    it "is the Chorus workspace whose workable points at it" do
      project = create(:appwork_manager_project)
      workspace = Appwork::Chorus::Workspace.create!(name: "Delivery", workable: project)
      expect(project.reload.workspace).to eq(workspace)
    end

    it "nullifies the hosting workspace's workable when destroyed" do
      project = create(:appwork_manager_project)
      workspace = Appwork::Chorus::Workspace.create!(name: "Delivery", workable: project)

      project.destroy

      expect(workspace.reload.workable_id).to be_nil
      expect(Appwork::Chorus::Workspace.exists?(workspace.id)).to be(true)
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
