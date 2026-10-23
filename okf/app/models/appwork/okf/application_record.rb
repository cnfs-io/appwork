module Appwork
  module Okf
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
