# frozen_string_literal: true

module Vauban
  # Methods extended onto Vauban for configuration (Vauban.configure, Vauban.config).
  module ConfigurationMethods
    attr_accessor :configuration

    # Yields or returns the configuration.
    #
    # @yield [config] optional block to set configuration values
    # @yieldparam config [Configuration]
    # @return [Configuration]
    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    # Returns the current configuration, initializing defaults if needed.
    # @return [Configuration]
    def config
      self.configuration ||= Configuration.new
    end
  end

  # Holds all Vauban configuration values.
  #
  # @attr_accessor current_user_method [Symbol] controller method that returns the current user (default: :current_user)
  # @attr_accessor cache_store [ActiveSupport::Cache::Store, nil] cache backend (default: nil, set to Rails.cache by Railtie)
  # @attr_accessor cache_ttl [Integer] cache TTL in seconds (default: 3600)
  # @attr_accessor policy_paths [Array<String>] glob patterns for policy auto-discovery
  class Configuration
    attr_accessor :current_user_method
    attr_accessor :cache_store
    attr_accessor :cache_ttl
    attr_accessor :policy_paths

    def initialize
      @current_user_method = :current_user
      @cache_store = nil
      @cache_ttl = 3600
      @policy_paths = [
        "app/policies/**/*_policy.rb",
        "packs/*/app/policies/**/*_policy.rb"
      ]
    end
  end
end
