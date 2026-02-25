# frozen_string_literal: true

module Vauban
  # Base class for authorization policies. Subclass and declare permissions:
  #
  #   class DocumentPolicy < Vauban::Policy
  #     resource Document
  #
  #     permission :view do
  #       allow_if { |doc, user| doc.owner == user }
  #     end
  #   end
  #
  class Policy
    # @return [Object] the user this policy instance is scoped to
    attr_reader :user

    class << self
      # @return [Class, nil] the model class this policy governs
      attr_accessor :resource_class

      # Declares which model class this policy governs.
      # @param klass [Class] the model class (e.g. Document)
      # @return [void]
      def resource(klass)
        self.resource_class = klass
      end

      # Defines a named permission with allow/deny rules.
      # When +relation:+ is set, an implicit allow_if { Vauban.has_relation?(user, relation, resource) } is added (with indirect traversal).
      #
      # @param name [Symbol] permission name (e.g. :view, :edit)
      # @param relation [Symbol, nil] optional ReBAC relation; if set, allowed when user has this relation (direct or via)
      # @yield block evaluated in the Permission DSL context (use allow_if / deny_if)
      # @return [Permission]
      def permission(name, relation: nil, &block)
        permissions[name] = Permission.new(name, relation: relation, &block)
      end

      # @return [Hash{Symbol => Permission}] all defined permissions
      def permissions
        @permissions ||= {}
      end

      # @return [Array<Symbol>] list of defined permission names
      def available_permissions
        permissions.keys
      end

      # @return [Hash{Symbol => Array<Symbol>}] for each relation, relations that imply it (e.g. viewer => [:editor, :owner])
      def relation_implied_by
        @relation_implied_by ||= {}
      end

      # @return [Hash{Symbol => Hash{Symbol => Class}}] for each relation, via rules e.g. { viewer: { member: Team } }
      def relation_via
        @relation_via ||= {}
      end

      # Declares a ReBAC relation and optional implications / indirect traversal for graph resolution.
      #
      #   relation :viewer
      #   relation :editor, requires: [:viewer]
      #   relation :owner, requires: [:editor, :viewer]
      #   relation :viewer, via: { member: Team }  # subject has viewer on doc if subject is member of a Team that has viewer on doc
      #
      # @param name [Symbol] relation name (e.g. :viewer, :editor)
      # @param requires [Array<Symbol>] relations that this relation implies (subject has this => has those too)
      # @param via [Hash{Symbol => Class}] indirect paths: relation_on_intermediate => intermediate_class (e.g. member: Team)
      # @return [void]
      def relation(name, requires: [], via: {})
        name = name.to_sym
        requires = requires.map(&:to_sym)
        requires.each do |r|
          relation_implied_by[r] ||= []
          relation_implied_by[r] << name unless relation_implied_by[r].include?(name)
        end
        relation_via[name] = via.transform_keys(&:to_sym).transform_values(&:itself).freeze unless via.empty?
      end

      # Returns the list of relations to check for "subject has this relation" including implications.
      # E.g. effective_relations(:viewer) => [:viewer, :editor, :owner] when editor requires viewer, owner requires editor and viewer.
      #
      # @param rel [Symbol]
      # @return [Array<Symbol>]
      def effective_relations(rel)
        rel = rel.to_sym
        [ rel ] + (relation_implied_by[rel] || []).freeze
      end

      # Returns the via rules for a relation (e.g. { member: Team }), or empty hash if none.
      #
      # @param rel [Symbol]
      # @return [Hash{Symbol => Class}]
      def relation_via_for(rel)
        relation_via[rel.to_sym] || {}
      end

      # @return [Hash{Symbol => Proc}] all defined relationships
      def relationships
        @relationships ||= {}
      end

      # Defines a named relationship for reuse in permission rules.
      #
      # @param name [Symbol] relationship name
      # @yield block evaluated in the resource's instance context
      # @return [void]
      def relationship(name, &block)
        relationships[name] = block
      end

      # @return [Hash{Symbol => Proc}] all defined conditions
      def conditions
        @conditions ||= {}
      end

      # Defines a named condition for reuse in permission rules.
      #
      # @param name [Symbol] condition name
      # @yield [resource, user, context] block that returns truthy/falsy
      # @return [void]
      def condition(name, &block)
        conditions[name] = block
      end

      # Defines a scope for use with {Vauban.accessible_by}.
      # When +relation:+ is set, the scope is built from the relation graph (direct + via); an optional block adds extra records (e.g. public docs).
      #
      # @param action [Symbol] the action this scope applies to (e.g. :view)
      # @param relation [Symbol, nil] optional ReBAC relation; if set, scope includes all resources where user has this relation
      # @yield [user, context] optional block; when relation is set, its result is unioned with the relation-based scope
      # @return [void]
      def scope(action, relation: nil, &block)
        action = action.to_sym
        scope_configs[action] = { relation: relation&.to_sym, block: block }
      end

      # @return [Hash{Symbol => Proc}] action => block (for backward compatibility when no relation)
      def scopes
        @scopes ||= scope_configs.transform_values { |c| c[:block] }
      end

      # @return [Hash{Symbol => Hash}] action => { relation:, block: }
      def scope_configs
        @scope_configs ||= {}
      end

      # Returns a thread-safe, memoized policy instance for the given user.
      #
      # @param user [Object] the user to scope this policy to
      # @return [Policy] a policy instance for the user
      def instance_for(user)
        @instances ||= Concurrent::Map.new
        user_key = Cache.user_key(user)
        user_instances = @instances.compute_if_absent(user_key) { Concurrent::Map.new }
        user_instances.compute_if_absent(self) { new(user) }
      end

      # Clears all memoized policy instances.
      # @return [void]
      def clear_instance_cache!
        @instances&.clear
      end
    end

    # @param user [Object] the user this policy is scoped to
    def initialize(user)
      @user = user
    end

    # Checks all permissions for a resource and returns a hash.
    #
    # @param resource [Object] the resource to check
    # @param context [Hash] optional context
    # @return [Hash{String => Boolean}] permission name → allowed
    def all_permissions(resource, context: {})
      self.class.permissions.each_with_object({}) do |(action, _), result|
        result[action.to_s] = allowed?(action, resource, context: context)
      end
    end

    # Checks whether the user is allowed to perform an action.
    #
    # @param action [Symbol] the permission name
    # @param resource [Object] the resource to check
    # @param context [Hash] optional context
    # @return [Boolean]
    def allowed?(action, resource, context: {})
      permission = self.class.permissions[action.to_sym]
      return false unless permission

      permission.allowed?(resource, @user, context: context, policy: self)
    end

    # Returns a scoped relation for the given action.
    #
    # @param action [Symbol] the scope name (e.g. :view)
    # @param context [Hash] optional context
    # @return [Object] typically an ActiveRecord::Relation
    # @raise [ArgumentError] if the resource class doesn't respond to .all
    def scope(action, context: {})
      raise ArgumentError, "#{resource_class} must respond to .all for scoping" unless resource_class.respond_to?(:all)

      config = self.class.scope_configs[action.to_sym]
      permission = self.class.permissions[action.to_sym]

      # Explicit scope config wins
      if config
        rel = config[:relation]
        scope_block = config[:block]

        if rel
          ids = Vauban.object_ids_for_relation(@user, rel, resource_class)
          base = ids.any? ? resource_class.where(id: ids) : resource_class.none
          if scope_block
            base = base.or(resource_class.instance_exec(@user, context, &scope_block))
          end
          return base.distinct
        end
        return resource_class.instance_exec(@user, context, &scope_block) if scope_block
      end

      # No explicit scope: auto-generate from allow_where if present (Path B)
      if permission&.allow_where_blocks&.any? && resource_class.respond_to?(:where)
        hashes = permission.evaluate_allow_where_blocks(@user, context, self)
        return AllowWhere.build_scope(resource_class, hashes) if hashes.any?
      end

      resource_class.all
    end

    # @return [Class] the resource class this policy governs
    def resource_class
      self.class.resource_class
    end

    # Evaluates a named relationship on a resource.
    #
    # @param name [Symbol] relationship name
    # @param resource [Object] the resource
    # @return [Object, nil] the relationship result, or nil if undefined
    def evaluate_relationship(name, resource)
      relationship_block = self.class.relationships[name]
      return nil unless relationship_block
      resource.instance_eval(&relationship_block)
    end

    # Evaluates a named condition.
    #
    # @param name [Symbol] condition name
    # @param resource [Object] the resource
    # @param context [Hash] optional context
    # @return [Object, nil] the condition result, or nil if undefined
    def evaluate_condition(name, resource, context)
      condition_block = self.class.conditions[name]
      return nil unless condition_block
      condition_block.call(resource, @user, context)
    end
  end
end
