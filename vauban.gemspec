# frozen_string_literal: true

require_relative "lib/vauban/version"

Gem::Specification.new do |spec|
  spec.name          = "vauban"
  spec.version       = Vauban::VERSION
  spec.authors       = [ "Clément Avenel" ]
  spec.email         = [ "contact@clement-avenel.com" ]

  spec.summary       = "Relationship-based authorization for Rails"
  spec.description   = "A Rails-first authorization gem using Relationship-Based Access Control (ReBAC) with a readable DSL and comprehensive tooling. Named after Sébastien Le Prestre de Vauban, the master builder of citadels."
  spec.homepage      = "https://github.com/clement-avenel/vauban"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/clement-avenel/vauban"
  spec.metadata["changelog_uri"]   = "https://github.com/clement-avenel/vauban/blob/main/CHANGELOG.md"

  spec.files = Dir["lib/**/*", "LICENSE.txt", "README.md", "CHANGELOG.md"]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "activesupport", ">= 6.0"
  spec.add_dependency "activerecord",  ">= 6.0"
  spec.add_dependency "railties",      ">= 6.0"
end
