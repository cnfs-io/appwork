# A minimal Chorus host model used only to unit-test the Appwork::Chorus::Workable
# concern in isolation from any real host's spine (mirrors how OKF's dummy
# defines consumer models). It keeps a concept for realism, but occupiability is
# concept-independent — Workable (post-006) is occupiability only, so the concern
# specs exercise a bare dummy with no concept.
class WorkableDummy < ApplicationRecord
  has_one_okf :concept

  include Appwork::Chorus::Workable
end
