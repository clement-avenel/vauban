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
      AssociationPreloader.new(@resources).call

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
            uncached_resources_with_keys << [ resource, key ]
          end
        end
      else
        # Fall back to individual cache checks (or no cache)
        resource_cache_keys.each do |resource, key|
          uncached_resources_with_keys << [ resource, key ]
        end
      end

      [ cached_results, uncached_resources_with_keys ]
    end

    def generate_cache_keys
      @resources.map do |resource|
        [ resource, Cache.key_for_all_permissions(@user, resource, context: @context) ]
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
