module Chorus
  # Idempotent demo seeds for a realistic, non-opinionated organization.
  # Runnable from the dummy app via `bin/rails db:seed` or `rake chorus:seed`.
  #
  # The graph follows the intent spine — organization → strategy → goal →
  # project → issue — with a separate execution surface of durable, serial
  # workspaces that each host one active project and carry artifacts.
  module Seeds
    module_function

    def seed!
      org = Organization.find_or_create_by!(slug: "acme-chorus") do |o|
        o.name = "Acme Chorus"
        o.description = "A non-opinionated demo organization for exploring the Chorus domain."
      end

      coordinator = org.roles.find_or_create_by!(name: "Coordinator") { |r| r.description = "Plans and sequences work." }
      maker       = org.roles.find_or_create_by!(name: "Maker")       { |r| r.description = "Does the building." }
      reviewer    = org.roles.find_or_create_by!(name: "Reviewer")    { |r| r.description = "Checks and approves." }

      ada    = org.agents.find_or_create_by!(name: "Ada")    { |a| a.kind = "human"; a.role = coordinator }
      turing = org.agents.find_or_create_by!(name: "Turing") { |a| a.kind = "human"; a.role = reviewer }
      echo   = org.agents.find_or_create_by!(name: "Echo")   { |a| a.kind = "ai";    a.role = maker }
      nova   = org.agents.find_or_create_by!(name: "Nova")   { |a| a.kind = "ai" } # deliberately unassigned

      # Intent spine: one active strategy, goals derived from it, projects under goals.
      strategy = org.strategies.find_or_create_by!(name: "Become the default coordination layer") do |s|
        s.status = "active"
        s.description = "Win adoption by staying unopinionated and easy to host."
      end

      delivery_goal = strategy.goals.find_or_create_by!(name: "Ship the flagship") do |g|
        g.status = "active"
        g.description = "Get the first product build into users' hands."
      end
      reliability_goal = strategy.goals.find_or_create_by!(name: "Keep the lights on") do |g|
        g.status = "active"
        g.description = "Operational reliability and security."
      end

      phoenix = delivery_goal.projects.find_or_create_by!(name: "Phoenix")    { |p| p.slug = "phoenix"; p.status = "active";   p.description = "The flagship build." }
      atlas   = delivery_goal.projects.find_or_create_by!(name: "Atlas")      { |p| p.slug = "atlas";   p.status = "planning"; p.description = "Next quarter's bets." }
      beacon  = reliability_goal.projects.find_or_create_by!(name: "Beacon")  { |p| p.slug = "beacon";  p.status = "on_hold";  p.description = "Reliability and security." }

      # Execution surface: durable workspaces, each hosting one active project.
      delivery = org.workspaces.find_or_create_by!(name: "Delivery") do |w|
        w.description = "Shipping product work."
        w.active_project = phoenix
      end
      operations = org.workspaces.find_or_create_by!(name: "Operations") do |w|
        w.description = "Keeping the lights on."
        w.active_project = beacon
      end

      seed_artifact(delivery,   "phoenix-app",   kind: "git_repo",   locator: "https://example.com/acme/phoenix.git")
      seed_artifact(delivery,   "design-bundle", kind: "okf_bundle", locator: "okf://acme/phoenix/design")
      seed_artifact(operations, "runbooks",      kind: "git_repo",   locator: "https://example.com/acme/runbooks.git")

      seed_issue(phoenix, "Set up CI",            status: "open",        position: 1, agent: echo)
      seed_issue(phoenix, "Write API spec",       status: "in_progress", position: 2, agent: ada)
      seed_issue(phoenix, "Review auth flow",     status: "blocked",     position: 3, agent: turing)
      seed_issue(atlas,   "Draft roadmap",        status: "open",        position: 1, agent: ada)
      seed_issue(atlas,   "Competitive analysis", status: "done",        position: 2, agent: nil)
      seed_issue(beacon,  "Rotate credentials",   status: "open",        position: 1, agent: nova)
      seed_issue(beacon,  "Audit logging",        status: "in_progress", position: 2, agent: echo)
      seed_issue(beacon,  "Incident runbook",     status: "open",        position: 3, agent: nil)

      org
    end

    def seed_artifact(workspace, name, kind:, locator:)
      workspace.artifacts.find_or_create_by!(name: name) do |a|
        a.kind = kind
        a.locator = locator
      end
    end

    def seed_issue(project, title, status:, position:, agent:)
      project.issues.find_or_create_by!(title: title) do |i|
        i.status = status
        i.position = position
        i.agent = agent
      end
    end
  end
end
