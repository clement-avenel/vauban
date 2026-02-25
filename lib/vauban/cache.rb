# frozen_string_literal: true

require "digest/sha2"

module Vauban
  # Cache layer for permission checks and policy lookups.
  # Handles key generation, memoization, and store operations.
  module Cache
    module_function

    # --- Key building ---

    # Builds a cache key for a single permission check.
    #
    # @param user [Object]
    # @param action [Symbol, String]
    # @param resource [Object]
    # @param context [Hash]
    # @return [String] cache key
    def key_for_permission(user, action, resource, context: {})
      if simple_case?(user, resource, context)
        tuple = [ :permission, user.id, action.to_s, resource.class.name, resource.id ]
        get_or_set_memo(tuple) { build_key("permission", user, action, resource, context) }
      else
        build_key("permission", user, action, resource, context)
      end
    end

    # Builds a cache key for an all-permissions check.
    #
    # @param user [Object]
    # @param resource [Object]
    # @param context [Hash]
    # @return [String] cache key
    def key_for_all_permissions(user, resource, context: {})
      if simple_case?(user, resource, context)
        tuple = [ :all_permissions, user.id, resource.class.name, resource.id ]
        get_or_set_memo(tuple) { build_key("all_permissions", user, nil, resource, context) }
      else
        build_key("all_permissions", user, nil, resource, context)
      end
    end

    # Builds a cache key for a policy class lookup.
    #
    # @param resource_class [Class]
    # @return [String] cache key
    def key_for_policy(resource_class)
      "vauban:policy:#{resource_class.respond_to?(:name) ? resource_class.name : resource_class}"
    end

    # Builds a cache key for relation-scope (object_ids_for_relation).
    # Used to cache accessible_by scope when using relation-based policies.
    #
    # @param subject [Object] user or subject (must respond to :id or :to_key)
    # @param relation [Symbol, String]
    # @param object_type [Class]
    # @return [String] cache key
    def key_for_relation_scope(subject, relation, object_type)
      type_name = object_type.respond_to?(:name) ? object_type.name : object_type.to_s
      "vauban:relation_scope:#{user_key(subject)}:#{relation}:#{type_name}"
    end

    # Returns a stable string key for the given user.
    #
    # @param user [Object, nil]
    # @return [String]
    def user_key(user)
      return "user:nil" if user.nil?
      "user:#{id_of(user)}"
    end

    # Returns a stable string key for the given resource.
    #
    # @param resource [Object, nil]
    # @return [String]
    def resource_key(resource)
      return "nil" if resource.nil?
      return "class:#{resource.name}" if resource.is_a?(Class)
      "#{resource.class.name}:#{id_of(resource)}"
    end

    # --- Store operations ---

    # Fetches a value from the cache store, falling back to the block on miss.
    #
    # @param key [String] cache key
    # @param ttl [Integer, nil] override TTL in seconds
    # @yield block to compute the value on cache miss
    # @return [Object] cached or computed value
    def fetch(key, ttl: nil, &block)
      return yield unless cache_enabled?

      cache_store.fetch(key, expires_in: ttl || Vauban.config.cache_ttl, &block)
    rescue StandardError => e
      ErrorHandler.handle_cache_error(e, key: key, &block)
    end

    # Deletes a single cache entry.
    #
    # @param key [String] cache key
    # @return [void]
    def delete(key)
      return unless cache_enabled?
      cache_store.delete(key)
    rescue StandardError => e
      ErrorHandler.handle_cache_error(e, key: key)
    end

    # Clears all Vauban cache entries.
    # @return [void]
    def clear
      clear_by_pattern("vauban:*", label: "clear")
    end

    # Clears cache entries related to a specific resource.
    #
    # @param resource [Object]
    # @return [void]
    def clear_for_resource(resource)
      return unless cache_enabled?
      clear_by_pattern("vauban:*:*:#{resource_key(resource)}:*", label: "clear_for_resource")
      return unless resource.respond_to?(:class) && !resource.is_a?(Class)
      clear_relation_scope_for_object_type(resource.class)
    end

    # Clears cache entries related to a specific user.
    # Also clears relation-scope caches for that user (accessible_by).
    #
    # @param user [Object]
    # @return [void]
    def clear_for_user(user)
      return unless cache_enabled?
      clear_by_pattern("vauban:*:#{user_key(user)}:*", label: "clear_for_user")
      clear_relation_scope_for_user(user)
    end

    # Clears only relation-scope caches for a user (e.g. after grant!/revoke!).
    #
    # @param user [Object]
    # @return [void]
    def clear_relation_scope_for_user(user)
      return unless cache_enabled?
      clear_by_pattern("vauban:relation_scope:#{user_key(user)}:*", label: "clear_relation_scope_for_user")
    end

    # Clears relation-scope caches for an object type (e.g. after revoke_all! on a resource).
    # Invalidates all users' cached scopes for that type.
    #
    # @param object_type [Class]
    # @return [void]
    def clear_relation_scope_for_object_type(object_type)
      return unless cache_enabled?
      type_name = object_type.respond_to?(:name) ? object_type.name : object_type.to_s
      clear_by_pattern("vauban:relation_scope:*:*:#{type_name}", label: "clear_relation_scope_for_object_type")
    end

    # Clears the in-process key memoization cache.
    # @return [void]
    def clear_key_cache!
      KEY_CACHE_MUTEX.synchronize { @key_cache = {} }
    end

    # --- Private ---

    def build_key(type, user, action, resource, context)
      parts = [ "vauban", type, user_key(user) ]
      parts << action if action
      parts << resource_key(resource)
      parts << context_key(context)
      parts.join(":")
    end

    def id_of(obj)
      return obj.id if obj.respond_to?(:id)
      return obj.to_key.join("-") if obj.respond_to?(:to_key)
      obj.object_id
    end

    def context_key(context)
      return "no_context" if context.nil? || context.empty?

      if context.size <= 3 && context.values.all? { |v| v.is_a?(String) || v.is_a?(Numeric) || v.is_a?(TrueClass) || v.is_a?(FalseClass) || v.nil? }
        "ctx:#{context.sort.map { |k, v| "#{k}=#{v}" }.join(",")}"
      else
        Digest::SHA256.hexdigest(context.sort.to_h.to_json)
      end
    end

    def simple_case?(user, resource, context)
      context.empty? &&
        resource.respond_to?(:id) && resource.id &&
        user&.respond_to?(:id) && user.id
    end

    KEY_CACHE_MUTEX = Mutex.new
    @key_cache = {}

    def get_or_set_memo(tuple)
      KEY_CACHE_MUTEX.synchronize do
        return @key_cache[tuple] if @key_cache.key?(tuple)

        key = yield
        @key_cache[tuple] = key.freeze
        key
      end
    end

    def clear_by_pattern(pattern, label:)
      return unless cache_enabled?

      if cache_store.respond_to?(:delete_matched)
        cache_store.delete_matched(pattern)
      elsif defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger.warn("Vauban: Cache store doesn't support delete_matched. Clear (#{label}) had no effect.")
      end
    rescue StandardError => e
      ErrorHandler.handle_cache_error(e, key: label)
    end

    def cache_enabled?
      !cache_store.nil?
    end

    def cache_store
      Vauban.config.cache_store
    end

    private_class_method :build_key, :id_of, :context_key, :simple_case?,
                         :get_or_set_memo,
                         :clear_by_pattern, :cache_enabled?, :cache_store
  end
end
