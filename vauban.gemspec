# frozen_string_literal: true

require_relative "lib/vauban/version"

Gem::Specification.new do |spec|
  spec.name          = "vauban"
  spec.version       = Vauban::VERSION
  spec.authors       = [ "Clément Avenel" ]
  spec.email         = [ "contact@clement-avenel.com" ]

  spec.summary       = "Relationship-based authorization for Rails"
  spec.description   = "A Rails-first authorization gem using Relationship-Based Access Control (ReBAC) with a readable DSL, comprehensive tooling, and frontend API support. Named after Sébastien Le Prestre de Vauban, the master builder of citadels."
  spec.homepage      = "https://github.com/clement-avenel/vauban"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0", "< 4.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/clement-avenel/vauban"
  spec.metadata["changelog_uri"] = "https://github.com/clement-avenel/vauban/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    files = begin
      # Check if .git directory exists first to avoid running git commands unnecessarily
      if Dir.exist?(".git") || File.exist?(".git")
        # Try to use git if available, otherwise fall back to Dir.glob
        # Use Open3 with stderr redirected to /dev/null to completely suppress git errors
        require "open3"
        null_device = RUBY_PLATFORM =~ /mswin|mingw/ ? "NUL" : "/dev/null"
        stdout, _stderr, status = Open3.capture3("git ls-files -z 2>#{null_device}")
        if status.success? && !stdout.empty?
          stdout.split("\x0").reject(&:empty?)
        else
          Dir.glob("**/*", File::FNM_DOTMATCH).reject { |f| File.directory?(f) }
        end
      else
        # Not a git repository, use Dir.glob fallback
        Dir.glob("**/*", File::FNM_DOTMATCH).reject { |f| File.directory?(f) }
      end
    rescue StandardError, LoadError
      # If anything goes wrong (including Open3 not available), use Dir.glob fallback
      Dir.glob("**/*", File::FNM_DOTMATCH).reject { |f| File.directory?(f) }
    end
    files.reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile .rspec_status])
    end
  end

  spec.require_paths = [ "lib" ]

  # Dependencies
  spec.add_dependency "activesupport", ">= 6.0"
  spec.add_dependency "activerecord", ">= 6.0"
  spec.add_dependency "railties", ">= 6.0"

  # Development dependencies
  spec.add_development_dependency "bundler", ">= 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rubocop", "~> 1.0"
  spec.add_development_dependency "rubocop-rails-omakase", "~> 1.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
end
