class Organization < ApplicationRecord
  has_many :strategies, dependent: :destroy
  has_many :goals, through: :strategies
  has_many :projects, through: :goals
  has_many :issues, through: :projects

  has_one_okf :bundle
  has_one_okf :concept
end
