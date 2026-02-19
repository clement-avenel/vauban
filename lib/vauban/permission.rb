# frozen_string_literal: true

module Vauban
  class Permission
    attr_reader :name, :rules

    def initialize(name, &block)
      @name = name
      @rules = []
      instance_eval(&block) if block_given?
    end

    def allow_if(&block)
      @rules << Rule.new(:allow, block)
    end

    def deny_if(&block)
      @rules << Rule.new(:deny, block)
    end

    def allowed?(resource, user, context: {}, policy: nil)
      # Check deny rules first
      @rules.each do |rule|
        next unless rule.type == :deny

        return false if evaluate_rule(rule, resource, user, context, policy)
      end

      # Check allow rules
      @rules.each do |rule|
        next unless rule.type == :allow

        return true if evaluate_rule(rule, resource, user, context, policy)
      end

      # Default deny
      false
    end

    private

    def evaluate_rule(rule, resource, user, context, policy)
      if policy
        policy.instance_exec(resource, user, context, &rule.block)
      else
        rule.block.call(resource, user, context)
      end
    rescue StandardError => e
      # Log error with detailed context but don't fail authorization
      if defined?(::Rails) && ::Rails.respond_to?(:logger) && ::Rails.logger
        log_permission_error(e, rule, resource, user, context, policy)
      end
      false
    end

    def log_permission_error(error, rule, resource, user, context, policy)
      resource_info = resource_info_string(resource)
      user_info = user_info_string(user)
      policy_info = policy ? policy.class.name : "none"
      rule_location = rule_location_string(rule)

      message = "Vauban permission evaluation error"
      message += "\n  Permission: :#{@name}"
      message += "\n  Rule type: #{rule.type}"
      message += "\n  Policy: #{policy_info}"
      message += "\n  Resource: #{resource_info}"
      message += "\n  User: #{user_info}"
      message += "\n  Context: #{context.inspect}" unless context.empty?
      message += "\n  Rule location: #{rule_location}" if rule_location
      message += "\n  Error: #{error.class.name}: #{error.message}"
      message += "\n  Backtrace:\n    #{error.backtrace&.first(5)&.join("\n    ")}"

      ::Rails.logger.error(message)
    end

    def resource_info_string(resource)
      return "nil" if resource.nil?
      return "#{resource.class.name}##{resource.id}" if resource.respond_to?(:id)
      resource.class.name
    end

    def user_info_string(user)
      return "nil" if user.nil?
      return "#{user.class.name}##{user.id}" if user.respond_to?(:id)
      user.class.name
    end

    def rule_location_string(rule)
      # Try to extract source location from the block
      return nil unless rule.block.respond_to?(:source_location)
      file, line = rule.block.source_location
      return nil unless file && line
      "#{file}:#{line}"
    rescue StandardError
      nil
    end

    Rule = Struct.new(:type, :block)
  end
end
