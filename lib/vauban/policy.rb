# frozen_string_literal: true

module Vauban
  class Policy
    class << self
      attr_accessor :resource_class

      def resource(klass)
        self.resource_class = klass
      end

      def permission(name, &block)
        permissions[name] = Permission.new(name, &block)
      end

      def permissions
        @permissions ||= {}
      end

      def available_permissions
        permissions.keys
      end

      def relationships
        @relationships ||= {}
      end

      def relationship(name, &block)
        relationships[name] = block
      end

      def conditions
        @conditions ||= {}
      end

      def condition(name, &block)
        conditions[name] = block
      end

      def scope(action, &block)
        scopes[action] = block
      end

      def scopes
        @scopes ||= {}
      end

      # Thread-safe memoization of policy instances per user.
      # Uses Concurrent::Map (available in all Rails apps via concurrent-ruby).
      def instance_for(user)
        @instances ||= Concurrent::Map.new
        user_key = Cache.user_key(user)
        user_instances = @instances.compute_if_absent(user_key) { Concurrent::Map.new }
        user_instances.compute_if_absent(self) { new(user) }
      end

      def clear_instance_cache!
        @instances&.clear
      end
    end

    def initialize(user)
      @user = user
    end

    def all_permissions(user, resource, context: {})
      self.class.permissions.each_with_object({}) do |(action, _), result|
        result[action.to_s] = allowed?(action, resource, user, context: context)
      end
    end

    def allowed?(action, resource, user, context: {})
      permission = self.class.permissions[action.to_sym]
      return false unless permission

      permission.allowed?(resource, user, context: context, policy: self)
    end

    def scope(user, action, context: {})
      scope_block = self.class.scopes[action.to_sym]
      return resource_class.all unless scope_block
      raise ArgumentError, "#{resource_class} must respond to .all for scoping" unless resource_class.respond_to?(:all)

      resource_class.instance_exec(user, context, &scope_block)
    end

    def resource_class
      self.class.resource_class
    end

    def evaluate_relationship(name, resource)
      relationship_block = self.class.relationships[name]
      return nil unless relationship_block
      resource.instance_eval(&relationship_block)
    end

    def evaluate_condition(name, resource, user, context)
      condition_block = self.class.conditions[name]
      return nil unless condition_block
      condition_block.call(resource, user, context)
    end
  end
end
