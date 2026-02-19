# frozen_string_literal: true

module Vauban
  # Provides consistent error handling patterns across Vauban
  module ErrorHandler
    module_function

    # Handle errors in authorization checks
    # Logs errors and returns false to fail-safe deny
    #
    # @param error [StandardError] The error that occurred
    # @param context [Hash] Optional context for logging
    # @return [false] Always returns false to deny access
    def handle_authorization_error(error, context: {})
      log_error(error, level: :error, context: context) if should_log?
      false
    end

    # Handle errors in non-critical operations (e.g., caching, preloading)
    # Logs warnings and allows execution to continue
    #
    # @param error [StandardError] The error that occurred
    # @param operation [String] Description of the operation that failed
    # @param context [Hash] Optional context for logging
    # @yield Block to execute if error occurs (fallback behavior)
    # @return Result of block execution or nil
    def handle_non_critical_error(error, operation:, context: {}, &block)
      log_error(error, level: :warn, operation: operation, context: context) if should_log?
      block&.call
    end

    # Handle errors in cache operations
    # Logs errors and executes fallback block
    #
    # @param error [StandardError] The error that occurred
    # @param key [String] Cache key that failed
    # @yield Block to execute as fallback
    # @return Result of block execution
    def handle_cache_error(error, key:, &block)
      log_cache_error(error, key) if should_log?
      block&.call
    end

    # Handle errors in permission rule evaluation
    # Logs detailed error information
    #
    # @param error [StandardError] The error that occurred
    # @param permission [String, Symbol] Permission name
    # @param rule_type [Symbol] Type of rule (:allow or :deny)
    # @param context [Hash] Additional context
    # @return [false] Always returns false to deny access
    def handle_permission_error(error, permission:, rule_type:, context: {})
      log_permission_error(error, permission: permission, rule_type: rule_type, context: context) if should_log?
      false
    end

    private

    module_function

    def should_log?
      defined?(::Rails) && ::Rails.respond_to?(:logger) && ::Rails.logger
    end

    def log_error(error, level: :error, operation: nil, context: {})
      return unless should_log?

      parts = [
        "Vauban error#{operation ? " in #{operation}" : ""}: #{error.class.name}: #{error.message}",
        ("Context: #{context.inspect}" unless context.empty?),
        ("Backtrace:\n    #{error.backtrace&.first(5)&.join("\n    ")}" if error.backtrace)
      ]

      message = ErrorMessageBuilder.build(*parts)
      ::Rails.logger.public_send(level, message)
    end

    def log_cache_error(error, key)
      return unless should_log?

      message = ErrorMessageBuilder.build(
        "Vauban cache error for key '#{key}': #{error.class.name}: #{error.message}"
      )
      ::Rails.logger.error(message)
    end

    def log_permission_error(error, permission:, rule_type:, context: {})
      return unless should_log?

      resource_info = context[:resource] ? ResourceIdentifier.resource_info_string(context[:resource]) : "unknown"
      user_info = context[:user] ? ResourceIdentifier.user_info_string(context[:user]) : "unknown"
      policy_info = context[:policy] ? context[:policy].class.name : "none"
      rule_location = context[:rule_location]

      parts = [
        "Vauban permission evaluation error",
        "Permission: :#{permission}",
        "Rule type: #{rule_type}",
        "Policy: #{policy_info}",
        "Resource: #{resource_info}",
        "User: #{user_info}",
        ("Context: #{context[:context].inspect}" if context[:context] && !context[:context].empty?),
        ("Rule location: #{rule_location}" if rule_location),
        "Error: #{error.class.name}: #{error.message}",
        ("Backtrace:\n    #{error.backtrace&.first(5)&.join("\n    ")}" if error.backtrace)
      ]

      message = ErrorMessageBuilder.build(*parts)
      ::Rails.logger.error(message)
    end
  end
end
