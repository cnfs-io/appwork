module Gtd
  # The ADR 0005 composition root — the ONE object where all three layers meet,
  # and the only file in this workspace where CnfsOkf and CnfsUi co-occur. It
  # wears three hats:
  #
  #   1. Content owner (010 / ADR 0005) — owns a CnfsOkf::Concept and satisfies the
  #      duck-typed content interface (`title` / `body` / `update_content`). The
  #      dependency arrow points cnfs_ui -> interface; nothing here includes a
  #      CnfsUi constant (mirrors Note).
  #   2. Placement subject (011 / ADR 0005) — appears on N boards via N placements,
  #      each with independent position. The arrow points cnfs_ui -> Action.
  #   3. Assertion honorer (011 / ADR 0006) — the workflow board's columns assert
  #      `status:<value>`; cnfs_ui relays that here and WE decide how to honor it.
  class Action < ApplicationRecord
    self.table_name = "gtd_actions"
    include CnfsOkf::Consumer

    belongs_to :project, class_name: "Gtd::Project", optional: true
    belongs_to :context, class_name: "Gtd::Context", optional: true

    # Presentation state lives in cnfs_ui; one Action -> three placements (workflow
    # / context / project boards), each independently positioned (ADR 0005 —
    # multi-board is free). Verbatim from Note: the arrow is cnfs_ui -> Action.
    has_many :placements, as: :subject, class_name: "CnfsUi::Placement",
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
    # GUARDED — unlike Note's naive `update!(attribute => value)`. Gtd::Action has
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
