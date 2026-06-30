namespace :chorus do
  desc "Seed a realistic, non-opinionated demo organization into the host app"
  task seed: :environment do
    require "chorus/seeds"
    org = Chorus::Seeds.seed!
    puts "Seeded #{org.name}: " \
         "#{org.strategies.count} strategies, #{org.goals.count} goals, " \
         "#{org.roles.count} roles, #{org.agents.count} agents, " \
         "#{org.workspaces.count} workspaces, #{org.projects.count} projects, " \
         "#{Chorus::Artifact.where(workspace: org.workspaces).count} artifacts, " \
         "#{Chorus::Issue.where(project: org.projects).count} issues."
  end
end
