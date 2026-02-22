# frozen_string_literal: true

module Vauban
  # Formats error/log messages and handles errors consistently across Vauban.
  # All handler methods are fail-safe (never raise).
  module ErrorHandler
    module_function

    # Human-readable name for any object: "nil", "User#123", "Document".
    #
    # @param obj [Object, nil]
    # @return [String]
    def display_name(obj)
      return "nil" if obj.nil?
      name = obj.is_a?(Class) ? obj.name : obj.class.name
      return "#{name}##{obj.id}" if obj.respond_to?(:id) && !obj.is_a?(Class)
      name
    end

    # Logs an authorization error and returns false.
    #
    # @param error [StandardError]
    # @param context [Hash]
    # @return [false]
    def handle_authorization_error(error, context: {})
      log(error, level: :error, context: context)
      false
    end

    # Logs a non-critical error as a warning, then runs the fallback block.
    #
    # @param error [StandardError]
    # @param operation [String] label for the failed operation
    # @param context [Hash]
    # @yield optional fallback
    # @return [Object, nil] the fallback result, or nil
    def handle_non_critical_error(error, operation:, context: {}, &block)
      log(error, level: :warn, label: operation, context: context)
      block&.call
    end

    # Logs a cache error, then runs the fallback block.
    #
    # @param error [StandardError]
    # @param key [String] the cache key involved
    # @yield optional fallback
    # @return [Object, nil] the fallback result, or nil
    def handle_cache_error(error, key:, &block)
      log(error, level: :error, label: "cache key '#{key}'")
      block&.call
    end

    # Logs a permission rule evaluation error and returns false.
    #
    # @param error [StandardError]
    # @param permission [Symbol]
    # @param rule_type [Symbol] :allow or :deny
    # @param context [Hash]
    # @return [false]
    def handle_permission_error(error, permission:, rule_type:, context: {})
      return false unless should_log?

      resource_info = context[:resource] ? display_name(context[:resource]) : "unknown"
      user_info = context[:user] ? display_name(context[:user]) : "unknown"

      parts = [
        "Vauban permission error: :#{permission} (#{rule_type})",
        "resource=#{resource_info} user=#{user_info} policy=#{context[:policy]&.class&.name || 'none'}",
        error_line(error)
      ]
      parts << "rule_location=#{context[:rule_location]}" if context[:rule_location]

      ::Rails.logger.error(parts.compact.join(" | "))
      false
    end

    # --- private ---

    def log(error, level: :error, label: nil, context: {})
      return unless should_log?

      msg = "Vauban"
      msg += " [#{label}]" if label
      msg += ": #{error_line(error)}"
      msg += " context=#{context.inspect}" unless context.empty?

      ::Rails.logger.public_send(level, msg)
    end

    def error_line(error)
      loc = error.backtrace&.first
      "#{error.class}: #{error.message}#{" at #{loc}" if loc}"
    end

    def should_log?
      defined?(::Rails) && ::Rails.respond_to?(:logger) && ::Rails.logger
    end

    private_class_method :log, :error_line, :should_log?
  end
end
