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
    # @param relation [Symbol, nil] when set, an allow_if { Vauban.has_relation?(user, relation, resource) } is added
    # @yield optional DSL block (use allow_if / deny_if / allow_where inside)
    def initialize(name, relation: nil, &block)
      @name = name
      @allow_rules = []
      @deny_rules = []
      @allow_where_blocks = []
      if relation
        rel = relation.to_sym
        @allow_rules << Rule.new(:allow, ->(resource, user, _context) { Vauban.has_relation?(user, rel, resource) })
      end
      instance_eval(&block) if block_given?
    end

    # Declarative condition hashes: block returns a Hash (or Array of Hashes) describing allowed attributes.
    # The same conditions are used for both runtime +can?+ (record matched against hash) and +accessible_by+
    # (SQL scope generated from hash). Define the rule once, get both checks and scoping.
    #
    # @yield [user, context] block that returns a Hash or Array of Hashes (e.g. +{ owner_id: user.id }+ or +{ public: true }+)
    # @return [void]
    def allow_where(&block)
      @allow_where_blocks << block if block
    end

    # @return [Array<Proc>] blocks that return condition hashes (for scope generation)
    def allow_where_blocks
      @allow_where_blocks
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
      if @allow_where_blocks.any?
        hashes = evaluate_allow_where_blocks(user, context, policy)
        return true if hashes.any? { |h| AllowWhere.record_matches_hash?(resource, h) }
      end
      @allow_rules.each { |rule| return true if evaluate_rule(rule, resource, user, context, policy) }
      false
    end

    # Evaluates all allow_where blocks with (user, context); returns a flat array of condition hashes.
    # Used by Policy to build scope when no explicit scope is defined.
    def evaluate_allow_where_blocks(user, context, policy = nil)
      @allow_where_blocks.flat_map do |block|
        result = policy ? policy.instance_exec(user, context, &block) : block.call(user, context)
        normalize_condition_hashes(result)
      end.compact
    end

    private

    def normalize_condition_hashes(value)
      case value
      when Hash then [ value ]
      when Array then value.flat_map { |v| normalize_condition_hashes(v) }
      else []
      end
    end

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
