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
      # Log error but don't fail authorization
      if defined?(::Rails) && ::Rails.respond_to?(:logger) && ::Rails.logger
        ::Rails.logger.error("Vauban permission evaluation error: #{e.message}")
      end
      false
    end

    Rule = Struct.new(:type, :block)
  end
end
