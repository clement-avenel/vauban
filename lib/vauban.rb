# frozen_string_literal: true

require "vauban/version"
require "vauban/core"
require "vauban/policy"
require "vauban/registry"
require "vauban/relationship"
require "vauban/permission"
require "vauban/configuration"
require "vauban/cache"

# Rails integration (auto-loaded if Rails is available)
if defined?(Rails)
  require "vauban/rails"
  require "vauban/engine"
end

module Vauban
  class Error < StandardError; end
  class Unauthorized < Error; end
  class PolicyNotFound < Error; end
  class ResourceNotFound < Error; end

  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    def config
      # Always ensure configuration is initialized
      self.configuration ||= Configuration.new
    end

    # Main authorization method
    def authorize(user, action, resource, context: {})
      policy_class = Registry.policy_for(resource.class)
      raise PolicyNotFound, "No policy found for #{resource.class.name}" unless policy_class

      # Use can? which is cached, but raise exception if not allowed
      allowed = can?(user, action, resource, context: context)
      raise Unauthorized, "Not authorized to #{action} #{resource.class.name}##{resource.id}" unless allowed

      true
    end

    # Check permission without raising
    def can?(user, action, resource, context: {})
      cache_key = Cache.key_for_permission(user, action, resource, context: context)

      Cache.fetch(cache_key) do
        policy_class = Registry.policy_for(resource.class)
        return false unless policy_class

        policy = policy_class.new(user)
        policy.allowed?(action, resource, user, context: context)
      end
    rescue StandardError
      false
    end

    # Get all permissions for a resource
    def all_permissions(user, resource, context: {})
      cache_key = Cache.key_for_all_permissions(user, resource, context: context)

      Cache.fetch(cache_key) do
        policy_class = Registry.policy_for(resource.class)
        return {} unless policy_class

        policy = policy_class.new(user)
        policy.all_permissions(user, resource, context: context)
      end
    end

    # Batch check permissions for multiple resources
    def batch_permissions(user, resources, context: {})
      resources.each_with_object({}) do |resource, result|
        result[resource] = all_permissions(user, resource, context: context)
      end
    end

    # Get accessible records (scoping)
    def accessible_by(user, action, resource_class, context: {})
      policy_class = Registry.policy_for(resource_class)
      raise PolicyNotFound, "No policy found for #{resource_class.name}" unless policy_class

      policy = policy_class.new(user)
      policy.scope(user, action, context: context)
    end

    # Clear all cached permissions
    def clear_cache!
      Cache.clear
    end

    # Clear cache for a specific resource (useful when resource is updated)
    def clear_cache_for_resource!(resource)
      Cache.clear_for_resource(resource)
    end

    # Clear cache for a specific user (useful when user permissions change)
    def clear_cache_for_user!(user)
      Cache.clear_for_user(user)
    end
  end
end
