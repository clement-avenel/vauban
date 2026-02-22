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
      #
      # @param name [Symbol] permission name (e.g. :view, :edit)
      # @yield block evaluated in the Permission DSL context (use allow_if / deny_if)
      # @return [Permission]
      def permission(name, &block)
        permissions[name] = Permission.new(name, &block)
      end

      # @return [Hash{Symbol => Permission}] all defined permissions
      def permissions
        @permissions ||= {}
      end

      # @return [Array<Symbol>] list of defined permission names
      def available_permissions
        permissions.keys
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
      #
      # @param action [Symbol] the action this scope applies to (e.g. :view)
      # @yield [user, context] block evaluated in the resource class context, should return a relation
      # @return [void]
      def scope(action, &block)
        scopes[action] = block
      end

      # @return [Hash{Symbol => Proc}] all defined scopes
      def scopes
        @scopes ||= {}
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

      scope_block = self.class.scopes[action.to_sym]
      return resource_class.all unless scope_block

      resource_class.instance_exec(@user, context, &scope_block)
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
