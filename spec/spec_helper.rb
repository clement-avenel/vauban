# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/.bundle/"
  add_filter "/vendor/"

  # Track coverage for lib files
  add_group "Core", "lib/vauban"
  add_group "Rails", "lib/vauban/rails"
  add_group "Generators", "lib/generators"

  # Minimum coverage threshold (optional, can be adjusted)
  # Note: Rails conditional loading (lib/vauban.rb lines 13-14) requires
  # running tests with rails_helper to achieve full coverage
  minimum_coverage 90
end

require "bundler/setup"
require "vauban"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
