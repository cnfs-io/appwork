require_relative "lib/appwork/chorus/version"

Gem::Specification.new do |spec|
  spec.name        = "appwork-chorus"
  spec.version     = Appwork::Chorus::VERSION
  spec.authors     = [ "Robert Roach" ]
  spec.email       = [ "rjayroach@gmail.com" ]
  spec.homepage    = "TODO"
  spec.summary     = "TODO: Summary of Appwork::Chorus."
  spec.description = "TODO: Description of Appwork::Chorus."
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
  # Config, Shell, Instrumentable, Logging, YamlSerializable and the plugin registry.
  # partitia-dev is optional (console helpers, behind defined?(Partitia::Dev)).
  spec.add_dependency "partitia-support"
  # Appwork::Chorus::ApplicationRecord includes Appwork::Okf::Consumer; WorkOrder runs Okf::Sync.
  spec.add_dependency "appwork-okf"
  # AgentProfile stores an encrypted API key via has_encrypted. Master key
  # wiring lives in the host app (see partitia-iam's gemspec note).
  spec.add_dependency "lockbox", "~> 2.0"
  spec.add_dependency "turbo-rails"
  spec.add_dependency "stimulus-rails"
  spec.add_dependency "importmap-rails"
  spec.add_dependency "tailwindcss-rails"
end
