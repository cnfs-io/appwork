module Appwork
  module Chorus
    class ApplicationRecord < ActiveRecord::Base
      include Appwork::Okf::Consumer

      self.abstract_class = true
    end
  end
end
