# frozen_string_literal: true

module Vauban
  # Methods extended onto Vauban for configuration (Vauban.configure, Vauban.config).
  module ConfigurationMethods
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    def config
      self.configuration ||= Configuration.new
    end
  end

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
