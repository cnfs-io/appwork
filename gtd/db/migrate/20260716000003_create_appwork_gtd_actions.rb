class CreateAppworkGtdActions < ActiveRecord::Migration[8.1]
  def change
    # A next action — the composition root (ADR 0005). Its title/body live in an
    # owned Appwork::Okf::Concept (on disk); the plain columns here are the domain
    # attributes: `status` (the GTD workflow enum — a plain string per the
    # vocabulary-fields convention, driven by the ADR 0006 assertion seam) plus
    # nullable FKs to its project and context (both optional groupings).
    create_table :appwork_gtd_actions do |t|
      t.references :project, null: true, foreign_key: { to_table: :appwork_gtd_projects }
      t.references :context, null: true, foreign_key: { to_table: :appwork_gtd_contexts }
      t.string :status

      t.timestamps
    end
  end
end
