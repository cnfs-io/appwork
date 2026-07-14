class Account < ApplicationRecord
  has_many :strategies, dependent: :destroy
  has_many :goals, through: :strategies

  has_one_okf :bundle
  has_one_okf :concept
end
