# frozen_string_literal: true

require "active_support/core_ext/numeric/time"

module Vauban
  class Configuration
    attr_accessor :current_user_method
    attr_accessor :cache_store
    attr_accessor :cache_ttl
    attr_accessor :audit_logger
    attr_accessor :frontend_api_enabled
    attr_accessor :frontend_cache_ttl
    attr_accessor :policy_paths

    def initialize
      @current_user_method = :current_user
      @cache_store = nil
      @cache_ttl = 1.hour
      @audit_logger = nil
      @frontend_api_enabled = true
      @frontend_cache_ttl = 5.minutes
      @policy_paths = [
        "app/policies/**/*_policy.rb",
        "packs/*/app/policies/**/*_policy.rb"
      ]
    end
  end
end
