module MicroManager
  class ApplicationRecord < ActiveRecord::Base
    include CnfsOkf::Consumer

    self.abstract_class = true
  end
end
