# frozen_string_literal: true

module Vauban
  # Handles batch permission checking for multiple resources with optimizations
  # for caching and association preloading
  class BatchPermissionChecker
    def initialize(user, resources, context: {})
      @user = user
      @resources = resources
      @context = context
    end

    def call
      return {} if @resources.empty?

      policy_classes = lookup_policy_classes
      preload_associations if active_record_available?
      
      cached_results, uncached_resources_with_keys = partition_by_cache_status
      uncached_results = process_uncached_resources(uncached_resources_with_keys, policy_classes)
      
      cached_results.merge(uncached_results)
    end

    private

    def lookup_policy_classes
      resources_by_class = @resources.group_by(&:class)
      policy_classes = {}
      
      resources_by_class.each_key do |resource_class|
        policy_classes[resource_class] = Registry.policy_for(resource_class)
      end
      
      policy_classes
    end

    def partition_by_cache_status
      resource_cache_keys = generate_cache_keys
      cached_results = {}
      uncached_resources_with_keys = []

      cache_store_instance = cache_store
      if cache_store_instance && cache_store_supports_read_multi?
        cached_values = cache_store_instance.read_multi(*resource_cache_keys.values)
        
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

      [cached_results, uncached_resources_with_keys]
    end

    def generate_cache_keys
      @resources.map do |resource|
        [resource, Cache.key_for_all_permissions(@user, resource, context: @context)]
      end.to_h
    end

    def process_uncached_resources(uncached_resources_with_keys, policy_classes)
      uncached_results = {}
      
      uncached_resources_with_keys.each do |resource, cache_key|
        permissions = Cache.fetch(cache_key) do
          policy_class = policy_classes[resource.class]
          if policy_class
            policy = policy_class.instance_for(@user)
            policy.all_permissions(@user, resource, context: @context)
          else
            {}
          end
        end
        
        uncached_results[resource] = permissions
      end
      
      uncached_results
    end

    def preload_associations
      return unless active_record_available?
      return if @resources.empty?

      resources_by_class = @resources.group_by(&:class)

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

    def active_record_available?
      defined?(ActiveRecord) && defined?(ActiveRecord::Base)
    end

    def cache_store_supports_read_multi?
      cache_store = Vauban.config.cache_store
      return false unless cache_store

      cache_store.respond_to?(:read_multi)
    end

    def cache_store
      Vauban.config.cache_store
    end
  end
end
