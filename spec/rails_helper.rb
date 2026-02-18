# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= "test"

# Load dummy app if it exists
dummy_path = File.expand_path("dummy", __dir__)
if Dir.exist?(dummy_path)
  # Ensure dummy app uses its own Gemfile before loading
  # Note: We don't set BUNDLE_GEMFILE here to avoid bundler trying to resolve
  # all dependencies (like optional gems). Instead, we rely on the dummy app's
  # environment to handle its own dependencies when loaded.
  dummy_gemfile = File.expand_path("dummy/Gemfile", __dir__)
  if File.exist?(dummy_gemfile)
    # Only set BUNDLE_GEMFILE if we're actually going to load the dummy app
    # This prevents bundler from trying to resolve optional dependencies
    ENV["BUNDLE_GEMFILE"] = dummy_gemfile
  end
  
  begin
    require File.expand_path("dummy/config/environment", __dir__)
    abort("The Rails environment is loading!") unless Rails.env.test?
    
    # Apply Ruby 4.0 compatibility patch after Rails loads
    if RUBY_VERSION >= "4.0" && defined?(ActionView::Template::Handlers::ERB)
      unless ActionView::Template::Handlers::ERB.const_defined?(:ENCODING_FLAG, false)
        ActionView::Template::Handlers::ERB.const_set(:ENCODING_FLAG, /<%#\s*(?:-\s*)?(?:en)?coding:\s*(\S+)\s*%>/)
      end
    end
  rescue LoadError, Gem::LoadError => e
    # Suppress thruster errors as it's optional (require: false)
    if e.message.include?("thruster")
      warn "⚠️  Note: thruster gem is optional and not installed. This is fine for testing."
      # Continue loading - thruster is optional
    elsif e.message.include?("bootsnap") || e.message.include?("bundler") || e.message.include?("sqlite3") || e.message.include?("is not part of the bundle")
      warn "⚠️  Dummy app dependencies not installed. Run: cd spec/dummy && bundle install"
      warn "Error: #{e.message}"
      raise
    else
      raise
    end
  end
else
  warn "⚠️  Dummy Rails app not found at #{dummy_path}"
  warn "The dummy app should be included in the repository. Please check out the repository or restore it from git."
  warn "Skipping Rails integration tests..."
end

require "rspec/rails"

# Require vauban core first
require "vauban"

# Ensure Vauban Rails integration is loaded after Rails is initialized
# The conditional require in lib/vauban.rb might not catch Rails in time
if defined?(Rails)
  require "vauban/rails"
  require "vauban/engine"
end

# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, you manually
# require only the support files necessary.
#
Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |f| require f }

# Load dummy app setup helpers
require File.expand_path("support/dummy_app_setup", __dir__)

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  warn "⚠️  Pending migrations detected. Run: cd spec/dummy && rails db:migrate RAILS_ENV=test"
  abort e.to_s.strip
rescue ActiveRecord::StatementInvalid => e
  if e.message.include?("no such table")
    warn "⚠️  Database tables missing. Run: cd spec/dummy && rails db:migrate RAILS_ENV=test"
    raise
  end
  raise
end

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [
    File.expand_path("fixtures", __dir__)
  ]

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, type: :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/6-0/rspec-rails
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
end
