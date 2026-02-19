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

  class Unauthorized < Error
    attr_reader :user, :action, :resource, :available_permissions

    def initialize(user, action, resource, available_permissions: nil, context: {})
      @user = user
      @action = action
      @resource = resource
      @available_permissions = available_permissions
      @context = context

      user_info = user_info_string(user)
      resource_info = resource_info_string(resource)
      permissions_info = permissions_info_string(available_permissions)

      message = build_message(user_info, resource_info, permissions_info)
      super(message)
    end

    private

    def build_message(user_info, resource_info, permissions_info)
      msg = "Not authorized to perform '#{@action}' on #{resource_info}"
      msg += "\n\nUser: #{user_info}" if user_info
      msg += "\n\nAvailable permissions: #{permissions_info}" if permissions_info
      msg += "\n\nTo debug:" unless @context.empty?
      msg += "\n  - Check your policy's :#{@action} permission rules"
      msg += "\n  - Verify the user has the required relationships"
      msg += "\n  - Review context: #{@context.inspect}" unless @context.empty?
      msg
    end

    def user_info_string(user)
      return "nil" if user.nil?
      return "#{user.class.name}##{user.respond_to?(:id) ? user.id : 'unknown'}" if user.respond_to?(:id)
      user.class.name
    end

    def resource_info_string(resource)
      return "nil" if resource.nil?
      return "#{resource.class.name}##{resource.id}" if resource.respond_to?(:id)
      resource.class.name
    end

    def permissions_info_string(permissions)
      return "none" if permissions.nil? || permissions.empty?
      permissions.map { |p| ":#{p}" }.join(", ")
    end
  end

  class PolicyNotFound < Error
    attr_reader :resource_class, :expected_policy_name

    def initialize(resource_class, context: {})
      @resource_class = resource_class
      resource_name = resource_class_name(resource_class)
      @expected_policy_name = "#{resource_name}Policy"
      @context = context

      message = build_message(resource_name)
      super(message)
    end

    private

    def resource_class_name(resource_class)
      return "Unknown" unless resource_class
      return resource_class.name if resource_class.respond_to?(:name) && resource_class.name
      return resource_class.to_s if resource_class.respond_to?(:to_s)
      resource_class.class.name
    end

    def underscore_class_name(class_name)
      return class_name unless class_name
      # Use ActiveSupport's underscore if available, otherwise use a simple fallback
      if defined?(ActiveSupport::Inflector)
        ActiveSupport::Inflector.underscore(class_name)
      else
        # Simple fallback: convert CamelCase to snake_case
        class_name.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                  .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                  .downcase
      end
    end

    def build_message(resource_name)
      msg = "No policy found for #{resource_name}"
      msg += "\n\nExpected policy class: #{@expected_policy_name}"
      msg += "\n\nTo fix this:"
      
      if resource_name != "Unknown"
        file_name = underscore_class_name(resource_name)
        msg += "\n  1. Create a policy file: app/policies/#{file_name}_policy.rb"
        msg += "\n  2. Define the policy class:"
        msg += "\n\n     class #{@expected_policy_name} < Vauban::Policy"
        msg += "\n       resource #{resource_name}"
        msg += "\n"
        msg += "\n       permission :view do"
        msg += "\n         allow_if { |resource, user| # your authorization logic }"
        msg += "\n       end"
        msg += "\n     end"
        msg += "\n\n  3. If using Packwerk, place it in: packs/*/app/policies/#{file_name}_policy.rb"
      else
        msg += "\n  1. Create a policy class that inherits from Vauban::Policy"
        msg += "\n  2. Register it using Vauban::Registry.register"
      end
      
      msg += "\n\nContext: #{@context.inspect}" unless @context.empty?
      msg
    end
  end

  class ResourceNotFound < Error
    attr_reader :resource_class, :identifier

    def initialize(resource_class, identifier: nil, context: {})
      @resource_class = resource_class
      @identifier = identifier
      @context = context

      message = build_message
      super(message)
    end

    private

    def build_message
      msg = "Resource not found"
      msg += "\n\nResource class: #{@resource_class.name}" if @resource_class
      msg += "\nIdentifier: #{@identifier.inspect}" if @identifier
      msg += "\n\nTo fix this:"
      msg += "\n  - Ensure the resource exists before authorization"
      msg += "\n  - Check that the identifier is correct"
      msg += "\n  - Verify the resource class is correct"
      msg += "\n\nContext: #{@context.inspect}" unless @context.empty?
      msg
    end
  end

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
      unless policy_class
        raise PolicyNotFound.new(resource.class, context: context)
      end

      # Use can? which is cached, but raise exception if not allowed
      allowed = can?(user, action, resource, context: context)
      unless allowed
        # Get available permissions for better error message
        available_permissions = policy_class.available_permissions if policy_class
        raise Unauthorized.new(user, action, resource, available_permissions: available_permissions, context: context)
      end

      true
    end

    # Check permission without raising
    def can?(user, action, resource, context: {})
      cache_key = Cache.key_for_permission(user, action, resource, context: context)

      Cache.fetch(cache_key) do
        policy_class = Registry.policy_for(resource.class)
        return false unless policy_class

        # Use memoized policy instance
        policy = policy_class.instance_for(user)
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

        # Use memoized policy instance
        policy = policy_class.instance_for(user)
        policy.all_permissions(user, resource, context: context)
      end
    end

    # Batch check permissions for multiple resources
    # Optimized to prevent N+1 queries by preloading associations and batch cache reads
    def batch_permissions(user, resources, context: {})
      return {} if resources.empty?

      # Group resources by class to optimize policy lookups
      resources_by_class = resources.group_by(&:class)
      
      # Memoize policy class lookups - lookup once per resource class
      policy_classes = {}
      resources_by_class.each_key do |resource_class|
        policy_classes[resource_class] = Registry.policy_for(resource_class)
      end
      
      # Preload associations for ActiveRecord resources to prevent N+1 queries
      preload_associations(resources) if active_record_available?

      # Generate all cache keys upfront
      resource_cache_keys = resources.map do |resource|
        [resource, Cache.key_for_all_permissions(user, resource, context: context)]
      end.to_h

      # Batch read from cache if supported
      cached_results = {}
      uncached_resources_with_keys = []

      cache_store_instance = cache_store
      if cache_store_instance && cache_store_supports_read_multi?
        # Try batch read from cache
        cache_keys_array = resource_cache_keys.values
        cached_values = cache_store_instance.read_multi(*cache_keys_array)

        resource_cache_keys.each do |resource, key|
          if cached_values.key?(key)
            cached_results[resource] = cached_values[key]
          else
            uncached_resources_with_keys << [resource, key]
          end
        end
      else
        # Fall back to individual cache checks (or no cache)
        resource_cache_keys.each do |resource, key|
          uncached_resources_with_keys << [resource, key]
        end
      end

      # Process uncached resources - compute permissions and cache them
      # Use pre-looked-up policy classes for better performance
      uncached_results = {}
      uncached_resources_with_keys.each do |resource, cache_key|
        # Use Cache.fetch which handles caching properly
        permissions = Cache.fetch(cache_key) do
          policy_class = policy_classes[resource.class]
          if policy_class
            policy = policy_class.instance_for(user)
            policy.all_permissions(user, resource, context: context)
          else
            {}
          end
        end
        
        uncached_results[resource] = permissions
      end

      # Merge cached and uncached results
      cached_results.merge(uncached_results)
    end

    # Get accessible records (scoping)
    def accessible_by(user, action, resource_class, context: {})
      policy_class = Registry.policy_for(resource_class)
      unless policy_class
        raise PolicyNotFound.new(resource_class, context: context)
      end

      # Use memoized policy instance
      policy = policy_class.instance_for(user)
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

    # Clear policy instance cache (useful for testing or when user permissions change)
    def clear_policy_instance_cache!
      Policy.clear_instance_cache!
    end

    private

    # Check if ActiveRecord is available
    def active_record_available?
      defined?(ActiveRecord) && defined?(ActiveRecord::Base)
    end

    # Check if cache store supports batch reads (read_multi)
    def cache_store_supports_read_multi?
      cache_store = Vauban.config.cache_store
      return false unless cache_store

      cache_store.respond_to?(:read_multi)
    end

    # Get cache store instance
    def cache_store
      Vauban.config.cache_store
    end

    # Preload common associations that might be used in permission checks
    # This prevents N+1 queries when checking permissions on multiple resources
    def preload_associations(resources)
      return unless active_record_available?
      return if resources.empty?

      # Group by class since different models have different associations
      resources_by_class = resources.group_by(&:class)

      resources_by_class.each do |resource_class, class_resources|
        # Only preload for ActiveRecord models
        next unless resource_class < ActiveRecord::Base

        # Filter to only ActiveRecord instances (not classes)
        ar_instances = class_resources.select { |r| r.is_a?(ActiveRecord::Base) }
        next if ar_instances.empty?

        # Common association names that are often used in permission checks
        # Users can override this behavior by preloading associations themselves
        common_associations = detect_common_associations(resource_class)

        if common_associations.any?
          # Use ActiveRecord's preloader API (Rails 6+)
          ActiveRecord::Associations::Preloader.new(
            records: ar_instances,
            associations: common_associations
          ).call
        end
      end
    rescue StandardError => e
      # If preloading fails, log but don't fail the authorization check
      # This is a performance optimization, not a critical feature
      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger.warn("Vauban: Failed to preload associations: #{e.message}")
      end
    end

    # Detect common association names that might be used in permission checks
    # This is a heuristic - users can always preload manually if needed
    def detect_common_associations(resource_class)
      associations = []
      
      # Check for common relationship patterns
      %w[owner user collaborator collaborators team members organization].each do |name|
        if resource_class.reflect_on_association(name.to_sym) ||
           resource_class.reflect_on_association(name.pluralize.to_sym)
          associations << name.to_sym
        end
      end

      # Also check for belongs_to associations (commonly used in permission checks)
      resource_class.reflect_on_all_associations(:belongs_to).each do |reflection|
        associations << reflection.name unless associations.include?(reflection.name)
      end

      associations
    end
  end
end
