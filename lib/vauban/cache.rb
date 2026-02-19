# frozen_string_literal: true

module Vauban
  # Cache manager for Vauban authorization checks
  class Cache
    class << self
      # Generate cache key for a permission check
      # Delegates to CacheKeyBuilder
      def key_for_permission(user, action, resource, context: {})
        CacheKeyBuilder.key_for_permission(user, action, resource, context: context)
      end

      # Generate cache key for all permissions on a resource
      # Delegates to CacheKeyBuilder
      def key_for_all_permissions(user, resource, context: {})
        CacheKeyBuilder.key_for_all_permissions(user, resource, context: context)
      end

      # Generate cache key for policy lookup
      # Delegates to CacheKeyBuilder
      def key_for_policy(resource_class)
        CacheKeyBuilder.key_for_policy(resource_class)
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

        resource_key = ResourceIdentifier.resource_key_for(resource)
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

        user_id = ResourceIdentifier.user_id_for(user)
        pattern = "vauban:*:#{user_id}:*"

        if cache_store.respond_to?(:delete_matched)
          cache_store.delete_matched(pattern)
        end
      rescue StandardError => e
        log_cache_error(e, "clear_for_user")
      end

      # Clear memoized cache keys (useful for testing)
      def clear_key_cache!
        CacheKeyBuilder.clear_key_cache!
      end

      private

      def cache_enabled?
        cache_store && !cache_store.nil?
      end

      def cache_store
        Vauban.config.cache_store
      end

      def log_cache_error(error, key)
        if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.error("Vauban cache error for key '#{key}': #{error.message}")
        end
      end
    end
  end
end
