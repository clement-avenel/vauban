ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# Bootsnap is optional - speeds up boot time by caching expensive operations
begin
  require "bootsnap/setup"
rescue LoadError
  # Bootsnap not available - continue without it
end
