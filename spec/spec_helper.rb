# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/.bundle/"
  add_filter "/vendor/"

  add_group "Core", "lib/vauban"
  add_group "Rails", "lib/vauban/rails"
  add_group "Generators", "lib/generators"

  minimum_coverage 90
end

require "bundler/setup"
require "vauban"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    Vauban::Registry.reset!
    Vauban::Cache.clear_key_cache!
    Vauban.configuration = nil
  end
end
