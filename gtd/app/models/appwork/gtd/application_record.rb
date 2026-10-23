module Appwork
  module Gtd
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
