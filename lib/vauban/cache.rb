# frozen_string_literal: true

require "digest"

module Vauban
  module Cache
    module_function

    # --- Key building ---

    def key_for_permission(user, action, resource, context: {})
      if simple_case?(user, resource, context)
        tuple = [ :permission, user.id, action.to_s, resource.class.name, resource.id ]
        get_or_set_memo(tuple) { build_key("permission", user, action, resource, context) }
      else
        build_key("permission", user, action, resource, context)
      end
    end

    def key_for_all_permissions(user, resource, context: {})
      if simple_case?(user, resource, context)
        tuple = [ :all_permissions, user.id, resource.class.name, resource.id ]
        get_or_set_memo(tuple) { build_key("all_permissions", user, nil, resource, context) }
      else
        build_key("all_permissions", user, nil, resource, context)
      end
    end

    def key_for_policy(resource_class)
      "vauban:policy:#{resource_class.respond_to?(:name) ? resource_class.name : resource_class}"
    end

    def user_key(user)
      return "user:nil" if user.nil?
      "user:#{id_of(user)}"
    end

    def resource_key(resource)
      return "nil" if resource.nil?
      return "class:#{resource.name}" if resource.is_a?(Class)
      "#{resource.class.name}:#{id_of(resource)}"
    end

    # --- Store operations ---

    def fetch(key, ttl: nil, &block)
      return yield unless cache_enabled?

      cache_store.fetch(key, expires_in: ttl || Vauban.config.cache_ttl, &block)
    rescue StandardError => e
      ErrorHandler.handle_cache_error(e, key: key, &block)
    end

    def delete(key)
      return unless cache_enabled?
      cache_store.delete(key)
    rescue StandardError => e
      ErrorHandler.handle_cache_error(e, key: key)
    end

    def clear
      clear_by_pattern("vauban:*", label: "clear")
    end

    def clear_for_resource(resource)
      return unless cache_enabled?
      clear_by_pattern("vauban:*:*:#{resource_key(resource)}:*", label: "clear_for_resource")
    end

    def clear_for_user(user)
      return unless cache_enabled?
      clear_by_pattern("vauban:*:#{user_key(user)}:*", label: "clear_for_user")
    end

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
        Digest::MD5.hexdigest(context.sort.to_h.to_json)
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
