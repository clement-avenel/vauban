# frozen_string_literal: true

module Vauban
  # Represents a single named permission with allow/deny rules.
  # Created via the {Policy.permission} DSL method.
  class Permission
    # @return [Symbol] the permission name
    attr_reader :name

    # @api private
    Rule = Struct.new(:type, :block)

    # @param name [Symbol] permission name
    # @yield optional DSL block (use allow_if / deny_if inside)
    def initialize(name, &block)
      @name = name
      @allow_rules = []
      @deny_rules = []
      instance_eval(&block) if block_given?
    end

    # Adds an allow rule. If any allow rule returns truthy, access is granted
    # (unless a deny rule already blocked it).
    #
    # @yield [resource, user, context] block that returns truthy to allow
    # @return [void]
    def allow_if(&block)
      @allow_rules << Rule.new(:allow, block)
    end

    # Adds a deny rule. Deny rules are evaluated before allow rules.
    # If any deny rule returns truthy, access is denied regardless of allow rules.
    #
    # @yield [resource, user, context] block that returns truthy to deny
    # @return [void]
    def deny_if(&block)
      @deny_rules << Rule.new(:deny, block)
    end

    # @return [Array<Rule>] all rules (deny first, then allow)
    def rules
      @deny_rules + @allow_rules
    end

    # Evaluates all rules to determine if access is allowed.
    #
    # @param resource [Object] the resource being accessed
    # @param user [Object] the current user
    # @param context [Hash] optional context
    # @param policy [Policy, nil] policy instance for instance_exec evaluation
    # @return [Boolean]
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
