# tailwindcss-rails hardcodes its entry file to app/assets/tailwind/application.css
# and hands it straight to the Tailwind CLI — it does NOT run ERB over it. So to
# drive @source lines from Partitia::Support.source_paths (and the tokens @import) we
# render the .erb entry into application.css ourselves, immediately before the
# build/watch CLI reads it.
#
# The rendered application.css holds ABSOLUTE, machine-specific paths and is a
# build artifact — it is gitignored; application.css.erb is the tracked source.
namespace :tailwindcss do
  desc "Render the ERB Tailwind entry (application.css.erb) into application.css"
  task render_entry: :environment do
    require "erb"

    dir = Rails.root.join("app/assets/tailwind")
    erb = dir.join("application.css.erb")
    next unless erb.exist?

    File.write(dir.join("application.css"), ERB.new(erb.read, trim_mode: "-").result)
  end
end

%w[tailwindcss:build tailwindcss:watch].each do |name|
  Rake::Task[name].enhance([ "tailwindcss:render_entry" ]) if Rake::Task.task_defined?(name)
end
