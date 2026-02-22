# frozen_string_literal: true

require "digest"

module Vauban
  # Builds cache keys for Vauban authorization checks
  # Handles memoization for common cases to improve performance
  class CacheKeyBuilder
    class << self
      def key_for_permission(user, action, resource, context: {})
        if simple_case?(user, resource, context)
          tuple = [ :permission, user.id, action.to_s, resource.class.name, resource.id ]
          get_or_set_memo(tuple) { build_permission_key(user, action, resource, context) }
        else
          build_permission_key(user, action, resource, context)
        end
      end

      def key_for_all_permissions(user, resource, context: {})
        if simple_case?(user, resource, context)
          tuple = [ :all_permissions, user.id, resource.class.name, resource.id ]
          get_or_set_memo(tuple) { build_all_permissions_key(user, resource, context) }
        else
          build_all_permissions_key(user, resource, context)
        end
      end

      # Generate cache key for policy lookup
      #
      # @param resource_class [Class] The resource class
      # @return [String] Cache key string
      def key_for_policy(resource_class)
        class_name = resource_class.respond_to?(:name) ? resource_class.name : resource_class.to_s
        "vauban:policy:#{class_name}"
      end

      def clear_key_cache!
        key_cache_mutex.synchronize { @key_cache = {} }
      end

      private

      def get_or_set_memo(tuple, &block)
        key_cache_mutex.synchronize do
          return @key_cache[tuple] if @key_cache&.key?(tuple)

          key = yield
          @key_cache ||= {}
          @key_cache[tuple] = key.freeze
          key
        end
      end

      def simple_case?(user, resource, context)
        context.empty? &&
          resource.respond_to?(:id) &&
          resource.id &&
          user&.respond_to?(:id) &&
          user.id
      end

      def key_cache_mutex
        @key_cache_mutex ||= Mutex.new
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
    end
  end
end
