require_relative "lib/gtd/version"

Gem::Specification.new do |spec|
  spec.name        = "gtd"
  spec.version     = Gtd::VERSION
  spec.authors     = [ "Robert Roach" ]
  spec.email       = [ "rjayroach@gmail.com" ]
  spec.homepage    = "TODO"
  spec.summary     = "TODO: Summary of Gtd."
  spec.description = "TODO: Description of Gtd."
  spec.license     = "MIT"

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

  # The ADR 0005 composition root depends on BOTH flanking layers — storage
  # (cnfs_okf: Concept + disk write path) and presentation (cnfs_ui: Board /
  # Column / Placement + Kanban components). Gtd::Action is the ONLY place they
  # meet; the two gems never reference each other. The UI stack (turbo, stimulus,
  # importmap, tailwindcss, phlex, view_component) arrives transitively through
  # cnfs_ui — declared once there, not re-stated here (gems/CLAUDE.md).
  spec.add_dependency "cnfs_okf"
  spec.add_dependency "cnfs_ui"
end
