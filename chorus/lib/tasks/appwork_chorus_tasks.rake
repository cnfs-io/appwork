namespace :chorus do
  desc "Seed the 007 frontend-builder console scenario into the host app"
  task seed: :environment do
    require "chorus/seeds"
    seeded = Chorus::Seeds.seed!
    puts "Seeded: profile #{seeded[:profile].name.inspect}, " \
         "agent #{seeded[:agent].name.inspect}, " \
         "role #{seeded[:role].name.inspect} " \
         "(#{seeded[:role].skill_requirements.count} skill requirements), " \
         "workspace #{seeded[:workspace].name.inspect}."
  end
end
