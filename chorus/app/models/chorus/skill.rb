module Chorus
  class Skill < ApplicationRecord
    # (No belongs_to :role: the org-position Role left Chorus in 004, and the 007
    # capability Role names its skills by requirement — it is not owned from Skill.
    # Issues are host-side.)
    has_one_okf :concept

    validates :name, presence: true
  end
end
