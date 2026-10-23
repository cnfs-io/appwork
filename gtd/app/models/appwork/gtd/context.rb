module Gtd
  # A GTD context (@home / @work / @calls) — a small grouping label. Not
  # concept-owning and not a placement subject: the context board is a pure view
  # (ADR 0005), so a Context only names a bucket that actions are grouped into.
  class Context < ApplicationRecord
    self.table_name = "gtd_contexts"

    has_many :actions, class_name: "Gtd::Action", dependent: :nullify
  end
end
