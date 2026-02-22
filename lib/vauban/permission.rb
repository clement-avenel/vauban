# frozen_string_literal: true

module Vauban
  class Permission
    attr_reader :name

    Rule = Struct.new(:type, :block)

    def initialize(name, &block)
      @name = name
      @allow_rules = []
      @deny_rules = []
      instance_eval(&block) if block_given?
    end

    def allow_if(&block)
      @allow_rules << Rule.new(:allow, block)
    end

    def deny_if(&block)
      @deny_rules << Rule.new(:deny, block)
    end

    def rules
      @deny_rules + @allow_rules
    end

    def allowed?(resource, user, context: {}, policy: nil)
      @deny_rules.each { |rule| return false if evaluate_rule(rule, resource, user, context, policy) }
      @allow_rules.each { |rule| return true if evaluate_rule(rule, resource, user, context, policy) }
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
      ErrorHandler.handle_permission_error(
        e,
        permission: @name,
        rule_type: rule.type,
        context: { resource: resource, user: user, policy: policy, context: context,
                   rule_location: rule.block.respond_to?(:source_location) ? rule.block.source_location&.join(":") : nil }
      )
      false
    end
  end
end
