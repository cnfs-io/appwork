module Appwork
  module Gtd
    # The ADR 0005 composition root — the ONE object where all three layers meet,
    # and the only file in this workspace where Appwork::Okf and Partitia::Ui co-occur. It
    # wears three hats:
    #
    #   1. Content owner (010 / ADR 0005) — owns a Appwork::Okf::Concept and satisfies the
    #      duck-typed content interface (`title` / `body` / `update_content`). The
    #      dependency arrow points partitia-ui -> interface; nothing here includes a
    #      Partitia::Ui constant (mirrors Note).
    #   2. Placement subject (011 / ADR 0005) — appears on N boards via N placements,
    #      each with independent position. The arrow points partitia-ui -> Action.
    #   3. Assertion honorer (011 / ADR 0006) — the workflow board's columns assert
    #      `status:<value>`; partitia-ui relays that here and WE decide how to honor it.
    class Action < ApplicationRecord
      self.table_name = "appwork_gtd_actions"
      include Appwork::Okf::Consumer

      belongs_to :project, class_name: "Appwork::Gtd::Project", optional: true
      belongs_to :context, class_name: "Appwork::Gtd::Context", optional: true

      # Presentation state lives in partitia-ui; one Action -> three placements (workflow
      # / context / project boards), each independently positioned (ADR 0005 —
      # multi-board is free). Verbatim from Note: the arrow is partitia-ui -> Action.
      has_many :placements, as: :subject, class_name: "Partitia::Ui::Placement",
               dependent: :destroy

      has_one_okf :concept

      # GTD workflow states. Plain strings, not a Rails enum (vocabulary-fields
      # convention). The workflow board's four columns ARE these values.
      STATUSES = %w[inbox next waiting done].freeze

      # --- content interface (010 / ADR 0005) ---------------------------------
      # Copied from Note: title delegates to the concept's frontmatter; body is the
      # concept's markdown body; update_content stages + saves through OKF's single
      # write path (assignment alone writes nothing).
      delegate :title, to: :concept, allow_nil: true

      def body = concept&.content

      def update_content(body:)
        concept.content = body
        concept.save!
      end

      # --- assertion honorer (011 / ADR 0006) ---------------------------------
      # The workflow board's columns declare `status:<value>`; the reposition
      # controller relays the destination column's (attribute, value) here on a
      # genuine cross-column move. Board-AGNOSTIC by design (ADR 0006): it switches
      # on the asserted *attribute*, never on which board/column called.
      #
      # GUARDED — unlike Note's naive `update!(attribute => value)`. Appwork::Gtd::Action has
      # real domain semantics, so an unexpected asserted attribute must be a safe
      # no-op, not a blind column write. Only `status` (the sole thing any column in
      # this spike asserts) is honored; the context/project boards are plain and
      # relay nothing, so nothing else should ever reach here — and if it does, it
      # does nothing.
      def satisfy_assertion(attribute:, value:)
        case attribute
        when :status then update!(status: value)
        else nil
        end
      end
    end
  end
end
