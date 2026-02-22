# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/.bundle/"
  add_filter "/vendor/"

  add_group "Core", "lib/vauban"
  add_group "Rails", "lib/vauban/rails"
  add_group "Generators", "lib/generators"

  minimum_coverage 80
end

ENV["RAILS_ENV"] ||= "test"

dummy_path = File.expand_path("dummy", __dir__)
if Dir.exist?(dummy_path)
  dummy_gemfile = File.expand_path("dummy/Gemfile", __dir__)
  ENV["BUNDLE_GEMFILE"] = dummy_gemfile if File.exist?(dummy_gemfile)

  begin
    require File.expand_path("dummy/config/environment", __dir__)
    abort("The Rails environment is loading!") unless Rails.env.test?
  rescue LoadError, Gem::LoadError => e
    if e.message.include?("thruster")
      warn "⚠️  Note: thruster gem is optional and not installed. This is fine for testing."
    else
      warn "⚠️  Dummy app dependency error: #{e.message}"
      raise
    end
  end
else
  warn "⚠️  Dummy Rails app not found at #{dummy_path}. Skipping Rails integration tests..."
end

require "rspec/rails"

require "vauban/railtie" unless defined?(Vauban::Railtie) if defined?(Rails)

Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |f| require f }

require File.expand_path("support/dummy_app_setup", __dir__)

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  warn "⚠️  Pending migrations detected. Run: cd spec/dummy && rails db:migrate RAILS_ENV=test"
  abort e.to_s.strip
rescue ActiveRecord::StatementInvalid => e
  raise unless e.message.include?("no such table")
  warn "⚠️  Database tables missing. Run: cd spec/dummy && rails db:migrate RAILS_ENV=test"
  raise
end

RSpec.configure do |config|
  config.fixture_paths = [ File.expand_path("fixtures", __dir__) ]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
