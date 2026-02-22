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
        # If caching fails, log error and execute block (fail-safe)
        ErrorHandler.handle_cache_error(e, key: key, &block)
      end

      # Delete cache entry
      def delete(key)
        return unless cache_enabled?

        cache_store.delete(key)
      rescue StandardError => e
        # Log error but don't fail - cache deletion is non-critical
        ErrorHandler.handle_cache_error(e, key: key)
      end

      def clear
        clear_by_pattern("vauban:*", key_for_log: "clear")
      end

      def clear_for_resource(resource)
        return unless cache_enabled?

        pattern = "vauban:*:*:#{ResourceIdentifier.resource_key_for(resource)}:*"
        clear_by_pattern(pattern, key_for_log: "clear_for_resource")
      end

      def clear_for_user(user)
        return unless cache_enabled?

        pattern = "vauban:*:#{ResourceIdentifier.user_id_for(user)}:*"
        clear_by_pattern(pattern, key_for_log: "clear_for_user")
      end

      # Clear memoized cache keys (useful for testing)
      def clear_key_cache!
        CacheKeyBuilder.clear_key_cache!
      end

      private

      def clear_by_pattern(pattern, key_for_log:)
        return unless cache_enabled?

        if cache_store.respond_to?(:delete_matched)
          cache_store.delete_matched(pattern)
        elsif defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
          Rails.logger.warn("Vauban: Cache store doesn't support delete_matched. Clear (#{key_for_log}) had no effect.")
        end
      rescue StandardError => e
        ErrorHandler.handle_cache_error(e, key: key_for_log)
      end

      def cache_enabled?
        !cache_store.nil?
      end

      def cache_store
        Vauban.config.cache_store
      end
    end
  end
end
