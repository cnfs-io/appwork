class Organization < ApplicationRecord
  include CnfsOkf::Consumer

  has_many :strategies, dependent: :destroy
  has_many :goals, through: :strategies
  has_many :projects, through: :goals
  has_many :issues, through: :projects

  owns_one_cnfs_okf :root_bundle # , class_name: "CnfsOkf::RootBundle"
  owns_one_cnfs_okf :concept            # org-info concept
end
