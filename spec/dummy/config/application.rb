require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
# require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Load migration version helper for dynamic migrations
require_relative "../lib/migration_version" if File.exist?(File.expand_path("../lib/migration_version.rb", __FILE__))

module Dummy
  class Application < Rails::Application
    # Initialize configuration defaults for the installed Rails version.
    # Dynamically determine the version to support multiple Rails versions in CI
    rails_version = "#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}"
    config.load_defaults rails_version

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # autoload_lib is only available in Rails 8.1+
    if Rails::VERSION::MAJOR > 8 || (Rails::VERSION::MAJOR == 8 && Rails::VERSION::MINOR >= 1)
      config.autoload_lib(ignore: %w[assets tasks])
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
