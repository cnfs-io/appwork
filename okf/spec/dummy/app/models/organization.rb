class Organization < ApplicationRecord
  include Okf::Consumer

  has_many :strategies, dependent: :destroy
  has_many :goals, through: :strategies
  has_many :projects, through: :goals
  has_many :issues, through: :projects

  owns_one_okf :root_bundle # , class_name: "Okf::RootBundle"
  owns_one_okf :concept            # org-info concept
end
