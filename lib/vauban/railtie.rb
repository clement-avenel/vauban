# frozen_string_literal: true

require "vauban"
require "vauban/engine"

# Explicitly load generators before Rails autoloader tries to find them
# This prevents autoloader from incorrectly nesting them under Vauban::Rails
if defined?(Rails)
  # Use absolute path to avoid autoloading issues
  require File.expand_path("../../generators/vauban/install_generator", __FILE__)
  require File.expand_path("../../generators/vauban/policy_generator", __FILE__)
end

module Vauban
  class Railtie < Rails::Railtie
    # Run early to initialize config, but after load_config_initializers so initializer files can override
    initializer "vauban.configure", after: :load_config_initializers do |app|
      # Only set defaults if not already configured
      Vauban.configure do |config|
        config.current_user_method ||= :current_user
        config.cache_store ||= Rails.cache if defined?(Rails.cache)
      end
    end

    initializer "vauban.discover_policies" do
      config.after_initialize do
        Vauban::Registry.discover_and_register
      end
    end
  end
end
