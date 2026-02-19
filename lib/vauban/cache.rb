# frozen_string_literal: true

require "digest"

module Vauban
  # Cache manager for Vauban authorization checks
  class Cache
    class << self
      # Generate cache key for a permission check
      # Memoizes keys for common cases (simple resources with IDs, no context)
      def key_for_permission(user, action, resource, context: {})
        # Memoize for simple cases to avoid repeated string operations
        if context.empty? && resource.respond_to?(:id) && resource.id && user&.respond_to?(:id) && user.id
          cache_key_tuple = [:permission, user.id, action.to_s, resource.class.name, resource.id]
          memoized_key = memoized_cache_key(cache_key_tuple)
          return memoized_key if memoized_key
        end

        # Generate normally for complex cases
        user_id = user_id_for(user)
        resource_key = resource_key_for(resource)
        context_key = context_key_for(context)
        key = "vauban:permission:#{user_id}:#{action}:#{resource_key}:#{context_key}"

        # Memoize if it was a simple case
        if context.empty? && resource.respond_to?(:id) && resource.id && user&.respond_to?(:id) && user.id
          cache_key_tuple = [:permission, user.id, action.to_s, resource.class.name, resource.id]
          memoize_cache_key(cache_key_tuple, key)
        end

        key
      end

      # Generate cache key for all permissions on a resource
      # Memoizes keys for common cases (simple resources with IDs, no context)
      def key_for_all_permissions(user, resource, context: {})
        # Memoize for simple cases to avoid repeated string operations
        if context.empty? && resource.respond_to?(:id) && resource.id && user&.respond_to?(:id) && user.id
          cache_key_tuple = [:all_permissions, user.id, resource.class.name, resource.id]
          memoized_key = memoized_cache_key(cache_key_tuple)
          return memoized_key if memoized_key
        end

        # Generate normally for complex cases
        user_id = user_id_for(user)
        resource_key = resource_key_for(resource)
        context_key = context_key_for(context)
        key = "vauban:all_permissions:#{user_id}:#{resource_key}:#{context_key}"

        # Memoize if it was a simple case
        if context.empty? && resource.respond_to?(:id) && resource.id && user&.respond_to?(:id) && user.id
          cache_key_tuple = [:all_permissions, user.id, resource.class.name, resource.id]
          memoize_cache_key(cache_key_tuple, key)
        end

        key
      end

      # Generate cache key for policy lookup
      def key_for_policy(resource_class)
        class_name = resource_class.respond_to?(:name) ? resource_class.name : resource_class.to_s
        "vauban:policy:#{class_name}"
      end

      # Fetch from cache or execute block and cache result
      def fetch(key, ttl: nil, &block)
        return yield unless cache_enabled?

        ttl ||= Vauban.config.cache_ttl

        cache_store.fetch(key, expires_in: ttl, &block)
      rescue StandardError => e
        # If caching fails, log error and execute block
        log_cache_error(e, key)
        yield
      end

      # Delete cache entry
      def delete(key)
        return unless cache_enabled?

        cache_store.delete(key)
      rescue StandardError => e
        log_cache_error(e, key)
      end

      # Clear all Vauban cache entries
      def clear
        return unless cache_enabled?

        if cache_store.respond_to?(:delete_matched)
          cache_store.delete_matched("vauban:*")
        else
          # For caches that don't support pattern matching, we can't clear selectively
          # Log a warning
          if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
            Rails.logger.warn("Vauban: Cache store doesn't support delete_matched. Cannot clear Vauban cache.")
          end
        end
      rescue StandardError => e
        log_cache_error(e, "clear")
      end

      # Clear cache for a specific resource (useful when resource is updated)
      def clear_for_resource(resource)
        return unless cache_enabled?

        resource_key = resource_key_for(resource)
        pattern = "vauban:*:*:#{resource_key}:*"

        if cache_store.respond_to?(:delete_matched)
          cache_store.delete_matched(pattern)
        end
      rescue StandardError => e
        log_cache_error(e, "clear_for_resource")
      end

      # Clear cache for a specific user (useful when user permissions change)
      def clear_for_user(user)
        return unless cache_enabled?

        user_id = user_id_for(user)
        pattern = "vauban:*:#{user_id}:*"

        if cache_store.respond_to?(:delete_matched)
          cache_store.delete_matched(pattern)
        end
      rescue StandardError => e
        log_cache_error(e, "clear_for_user")
      end

      private

      def cache_enabled?
        cache_store && !cache_store.nil?
      end

      def cache_store
        Vauban.config.cache_store
      end

      def user_id_for(user)
        return "user:nil" if user.nil?

        if user.respond_to?(:id)
          "user:#{user.id}"
        elsif user.respond_to?(:to_key)
          "user:#{user.to_key.join('-')}"
        else
          "user:#{user.object_id}"
        end
      end

      def resource_key_for(resource)
        return "nil" if resource.nil?

        if resource.respond_to?(:id)
          "#{resource.class.name}:#{resource.id}"
        elsif resource.is_a?(Class)
          "class:#{resource.name}"
        else
          "#{resource.class.name}:#{resource.object_id}"
        end
      end

      def context_key_for(context)
        return "no_context" if context.nil? || context.empty?

        # Optimize for small, simple contexts - use direct string representation
        # Only hash for complex contexts (large or with complex values)
        if context.size <= 3 && context.values.all? { |v| v.is_a?(String) || v.is_a?(Numeric) || v.is_a?(TrueClass) || v.is_a?(FalseClass) || v.nil? }
          sorted = context.sort
          "ctx:#{sorted.map { |k, v| "#{k}=#{v}" }.join(',')}"
        else
          # Hash for complex contexts to keep keys manageable
          sorted_context = context.sort.to_h
          Digest::MD5.hexdigest(sorted_context.to_json)
        end
      end

      def log_cache_error(error, key)
        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.error("Vauban cache error for key '#{key}': #{error.message}")
        end
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

      # Clear memoized cache keys (useful for testing)
      def clear_key_cache!
        @key_cache_mutex ||= Mutex.new
        @key_cache_mutex.synchronize do
          @key_cache = {}
        end
      end
    end
  end
end
