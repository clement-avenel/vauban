# frozen_string_literal: true

module Vauban
  class Permission
    attr_reader :name, :rules

    def initialize(name, &block)
      @name = name
      @rules = []
      @allow_rules = []
      @deny_rules = []
      instance_eval(&block) if block_given?
    end

    def allow_if(&block)
      rule = Rule.new(:allow, block)
      @rules << rule
      @allow_rules << rule
    end

    def deny_if(&block)
      rule = Rule.new(:deny, block)
      @rules << rule
      @deny_rules << rule
    end

    def allowed?(resource, user, context: {}, policy: nil)
      # Check deny rules first (no type checking needed - already separated)
      @deny_rules.each do |rule|
        return false if evaluate_rule(rule, resource, user, context, policy)
      end

      # Check allow rules (no type checking needed - already separated)
      @allow_rules.each do |rule|
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
      rule_location = rule_location_string(rule)
      ErrorHandler.handle_permission_error(
        e,
        permission: @name,
        rule_type: rule.type,
        context: {
          resource: resource,
          user: user,
          policy: policy,
          context: context,
          rule_location: rule_location
        }
      )
      false
    end

    def rule_location_string(rule)
      # Try to extract source location from the block
      return nil unless rule.block.respond_to?(:source_location)
      file, line = rule.block.source_location
      return nil unless file && line
      "#{file}:#{line}"
    rescue StandardError => e
      # Silently ignore errors when extracting source location
      nil
    end

    Rule = Struct.new(:type, :block)
  end
end
