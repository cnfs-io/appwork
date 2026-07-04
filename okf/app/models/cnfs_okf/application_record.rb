module CnfsOkf
  class ApplicationRecord < ActiveRecord::Base
    include CnfsSupport::Logging

    self.abstract_class = true
  end
end
