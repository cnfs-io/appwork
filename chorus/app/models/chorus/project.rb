module Chorus
  class Project < ApplicationRecord
    belongs_to :goal
    has_one :strategy, through: :goal

    # A project is hosted by at most one workspace at a time (the workspace whose
    # active_project_id points at it). Inverse of Workspace#active_project.
    has_one :hosting_workspace, class_name: "Chorus::Workspace",
      foreign_key: :active_project_id, inverse_of: :active_project,
      dependent: :nullify

    has_many :issues, dependent: :destroy

    validates :name, presence: true
  end
end
