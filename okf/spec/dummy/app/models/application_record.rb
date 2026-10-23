class ApplicationRecord < ActiveRecord::Base
  include Partitia::Support::Logging
  include Appwork::Okf::Consumer

  primary_abstract_class
end
