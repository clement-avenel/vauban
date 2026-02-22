# frozen_string_literal: true

module Vauban
  # Formats error/log messages and handles errors consistently across Vauban.
  # Public: display_name, handle_*_error. All fail-safe (never raise).
  module ErrorHandler
    module_function

    # Human-readable name for any object: "nil", "User#123", "Document".
    def display_name(obj)
      return "nil" if obj.nil?
      name = obj.is_a?(Class) ? obj.name : obj.class.name
      return "#{name}##{obj.id}" if obj.respond_to?(:id) && !obj.is_a?(Class)
      name
    end

    def handle_authorization_error(error, context: {})
      log(error, level: :error, context: context)
      false
    end

    def handle_non_critical_error(error, operation:, context: {}, &block)
      log(error, level: :warn, label: operation, context: context)
      block&.call
    end

    def handle_cache_error(error, key:, &block)
      log(error, level: :error, label: "cache key '#{key}'")
      block&.call
    end

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
