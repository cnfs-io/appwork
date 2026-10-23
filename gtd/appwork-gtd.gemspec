require_relative "lib/appwork/gtd/version"

Gem::Specification.new do |spec|
  spec.name        = "appwork-gtd"
  spec.version     = Appwork::Gtd::VERSION
  spec.authors     = [ "Robert Roach" ]
  spec.email       = [ "rjayroach@gmail.com" ]
  spec.homepage    = "TODO"
  spec.summary     = "TODO: Summary of Appwork::Gtd."
  spec.description = "TODO: Description of Appwork::Gtd."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.1.3"

  spec.add_dependency "partitia-support"
  # The ADR 0005 composition root depends on BOTH flanking layers — storage
  # (appwork-okf: Concept + disk write path) and presentation (partitia-ui: Board /
  # Column / Placement + Kanban components). Appwork::Gtd::Action is the ONLY place
  # they meet; the two gems never reference each other. The UI stack (turbo,
  # stimulus, importmap, tailwindcss, phlex) arrives transitively through
  # partitia-ui. NOTE: partitia-ui has no Board/Column/Placement or Kanban
  # components today (see ROADMAP.md), so the board half of gtd does not load.
  spec.add_dependency "appwork-okf"
  spec.add_dependency "partitia-ui"
end
