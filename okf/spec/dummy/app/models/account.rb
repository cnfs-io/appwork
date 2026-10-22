class Account < ApplicationRecord
  has_many :strategies, dependent: :destroy
  has_many :goals, through: :strategies

  has_many_okf :bundles
end
