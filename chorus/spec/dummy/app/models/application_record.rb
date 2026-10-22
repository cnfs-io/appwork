class ApplicationRecord < ActiveRecord::Base
  # The dummy app plays a Chorus host: its models are OKF consumers (so a dummy
  # workable can `has_one_okf :concept`), mirroring how a real host's
  # ApplicationRecord is wired.
  include CnfsOkf::Consumer

  primary_abstract_class
end
