require_relative "lib/appwork/okf/version"

Gem::Specification.new do |spec|
  spec.name        = "appwork-okf"
  spec.version     = Appwork::Okf::VERSION
  spec.authors     = [ "Robert Roach" ]
  spec.email       = [ "rjayroach@gmail.com" ]
  spec.homepage    = "https://okf.org"
  spec.summary     = "Filesystem-backed OKF content engine for Rails."
  spec.description = "Appwork::Okf projects directories of OKF-style Markdown (bundles of " \
                    "frontmatter concepts) into ActiveRecord and keeps the projection " \
                    "reconciled with disk. Consumer models own concepts via a polymorphic " \
                    "association."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.1.3"
  spec.add_dependency "partitia-support"
  spec.add_dependency "listen"
  spec.add_dependency "turbo-rails"
  spec.add_dependency "stimulus-rails"
  spec.add_dependency "importmap-rails"
  spec.add_dependency "tailwindcss-rails"
end
