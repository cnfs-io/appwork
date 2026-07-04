class ApplicationRecord < ActiveRecord::Base
  include CnfsSupport::Logging
  include CnfsOkf::Consumer

  primary_abstract_class
end
