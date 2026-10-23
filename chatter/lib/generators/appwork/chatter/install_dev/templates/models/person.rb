# ⚠️  DEV/TEST SCAFFOLD — written by `bin/rails g appwork:chatter:install_dev`.
# A host-side participant model so chatter has something to talk as. In a real
# host these are your existing domain models (User, etc.) that include
# Appwork::Chatter::Participant — you would NOT generate this. Safe to delete when done.
class Person < ApplicationRecord
  include Appwork::Chatter::Participant

  validates :name, presence: true

  def chatter_display_name
    name
  end
end
