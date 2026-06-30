module Chorus
  class Organization < ApplicationRecord
    BUNDLE_ROOT = Rails.root.join("tmp/bundles").mkpath

    include Okf::ConsumesConcept

    has_one :bundle, class_name: "Okf::Bundle", dependent: :nullify

    has_many :strategies, dependent: :destroy
    has_many :goals, through: :strategies
    has_many :projects, through: :goals
    has_many :issues, through: :projects

    has_many :roles, dependent: :destroy
    has_many :agents, dependent: :destroy

    has_many :workspaces, dependent: :destroy

    validates :name, presence: true
    validates :slug, uniqueness: true, allow_blank: true

    def cbd
      Okf::Bundle.create(name: name, path: BUNDLE_ROOT.join(name).mkpath.to_s)
    end
  end
end
