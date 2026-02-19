# frozen_string_literal: true

require "digest"

module Vauban
  # Builds cache keys for Vauban authorization checks
  # Handles memoization for common cases to improve performance
  class CacheKeyBuilder
    class << self
      # Generate cache key for a permission check
      # Memoizes keys for common cases (simple resources with IDs, no context)
      #
      # @param user [Object] The user object
      # @param action [Symbol, String] The action being checked
      # @param resource [Object] The resource being checked
      # @param context [Hash] Optional context hash
      # @return [String] Cache key string
      def key_for_permission(user, action, resource, context: {})
        # Memoize for simple cases to avoid repeated string operations
        if simple_case?(user, resource, context)
          cache_key_tuple = [:permission, user.id, action.to_s, resource.class.name, resource.id]
          memoized_key = memoized_cache_key(cache_key_tuple)
          return memoized_key if memoized_key
        end

        # Generate normally for complex cases
        key = build_permission_key(user, action, resource, context)

        # Memoize if it was a simple case
        if simple_case?(user, resource, context)
          cache_key_tuple = [:permission, user.id, action.to_s, resource.class.name, resource.id]
          memoize_cache_key(cache_key_tuple, key)
        end

        key
      end

      # Generate cache key for all permissions on a resource
      # Memoizes keys for common cases (simple resources with IDs, no context)
      #
      # @param user [Object] The user object
      # @param resource [Object] The resource being checked
      # @param context [Hash] Optional context hash
      # @return [String] Cache key string
      def key_for_all_permissions(user, resource, context: {})
        # Memoize for simple cases to avoid repeated string operations
        if simple_case?(user, resource, context)
          cache_key_tuple = [:all_permissions, user.id, resource.class.name, resource.id]
          memoized_key = memoized_cache_key(cache_key_tuple)
          return memoized_key if memoized_key
        end

        # Generate normally for complex cases
        key = build_all_permissions_key(user, resource, context)

        # Memoize if it was a simple case
        if simple_case?(user, resource, context)
          cache_key_tuple = [:all_permissions, user.id, resource.class.name, resource.id]
          memoize_cache_key(cache_key_tuple, key)
        end

        key
      end

      # Generate cache key for policy lookup
      #
      # @param resource_class [Class] The resource class
      # @return [String] Cache key string
      def key_for_policy(resource_class)
        class_name = resource_class.respond_to?(:name) ? resource_class.name : resource_class.to_s
        "vauban:policy:#{class_name}"
      end

      # Clear memoized cache keys (useful for testing)
      def clear_key_cache!
        @key_cache_mutex ||= Mutex.new
        @key_cache_mutex.synchronize do
          @key_cache = {}
        end
      end

      private

      def simple_case?(user, resource, context)
        context.empty? &&
          resource.respond_to?(:id) &&
          resource.id &&
          user&.respond_to?(:id) &&
          user.id
      end

      def build_permission_key(user, action, resource, context)
        user_id = ResourceIdentifier.user_id_for(user)
        resource_key = ResourceIdentifier.resource_key_for(resource)
        context_key = context_key_for(context)
        "vauban:permission:#{user_id}:#{action}:#{resource_key}:#{context_key}"
      end

      def build_all_permissions_key(user, resource, context)
        user_id = ResourceIdentifier.user_id_for(user)
        resource_key = ResourceIdentifier.resource_key_for(resource)
        context_key = context_key_for(context)
        "vauban:all_permissions:#{user_id}:#{resource_key}:#{context_key}"
      end

      def context_key_for(context)
        return "no_context" if context.nil? || context.empty?

        # Optimize for small, simple contexts - use direct string representation
        # Only hash for complex contexts (large or with complex values)
        if context.size <= 3 && context.values.all? { |v| simple_value?(v) }
          sorted = context.sort
          "ctx:#{sorted.map { |k, v| "#{k}=#{v}" }.join(',')}"
        else
          # Hash for complex contexts to keep keys manageable
          sorted_context = context.sort.to_h
          Digest::MD5.hexdigest(sorted_context.to_json)
        end
      end

      def simple_value?(value)
        value.is_a?(String) ||
          value.is_a?(Numeric) ||
          value.is_a?(TrueClass) ||
          value.is_a?(FalseClass) ||
          value.nil?
      end

      # Memoize cache keys for common cases to avoid repeated string operations
      def memoized_cache_key(tuple)
        @key_cache ||= {}
        @key_cache_mutex ||= Mutex.new
        @key_cache_mutex.synchronize do
          @key_cache[tuple]
        end
      end

      def memoize_cache_key(tuple, key)
        @key_cache ||= {}
        @key_cache_mutex ||= Mutex.new
        @key_cache_mutex.synchronize do
          @key_cache[tuple] = key.freeze
        end
      end
    end
  end
end
