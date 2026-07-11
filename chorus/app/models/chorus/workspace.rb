module Chorus
  class Workspace < ApplicationRecord
    belongs_to :active_project, class_name: "Chorus::Project",
      optional: true, inverse_of: :hosting_workspace

    has_many :artifacts, dependent: :destroy

    validates :name, presence: true
  end
end
