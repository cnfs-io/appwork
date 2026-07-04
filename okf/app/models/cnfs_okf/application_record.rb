module CnfsOkf
  class ApplicationRecord < ActiveRecord::Base
    include CnfsSupport::Model

    self.abstract_class = true
  end
end
