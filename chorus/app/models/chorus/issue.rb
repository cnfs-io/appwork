module Chorus
  class Issue < ApplicationRecord
    belongs_to :project
    belongs_to :agent, optional: true

    validates :title, presence: true
  end
end
