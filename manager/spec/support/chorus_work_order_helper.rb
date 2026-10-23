# frozen_string_literal: true

# A Chorus work order naming a manager record as its subject (chorus plan 011 §4: the
# subject rides on WorkOrder, not on Workspace). Chorus' factories are not loaded here,
# so build the minimum it validates: a role, a workspace for it, the work order.
module ChorusWorkOrderHelper
  def chorus_work_order_for(workable)
    role = Appwork::Chorus::Role.create!(name: "Role #{SecureRandom.hex(3)}")
    workspace = Appwork::Chorus::Workspace.create!(name: "Workspace #{SecureRandom.hex(3)}", role: role)
    Appwork::Chorus::WorkOrder.create!(workable: workable, workspace: workspace, role: role)
  end
end

RSpec.configure { |config| config.include ChorusWorkOrderHelper }
