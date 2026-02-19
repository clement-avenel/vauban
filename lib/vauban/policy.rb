# frozen_string_literal: true

module Vauban
  class Policy
    class << self
      attr_accessor :resource_class, :package, :depends_on

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
    end

    def initialize(user)
      @user = user
    end

    # Memoize policy instances per user to avoid recreating them
    def self.instance_for(user)
      @instances ||= {}
      @instances_mutex ||= Mutex.new

      user_key = user_key_for(user)
      
      @instances_mutex.synchronize do
        @instances[user_key] ||= {}
        @instances[user_key][self] ||= new(user)
      end
    end

    def self.clear_instance_cache!
      @instances_mutex ||= Mutex.new
      @instances_mutex.synchronize do
        @instances = {}
      end
    end

    # Public method to get all permissions for a resource
    def all_permissions(user, resource, context: {})
      self.class.permissions.each_with_object({}) do |(action, _permission), result|
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

      if resource_class.respond_to?(:all)
        resource_class.instance_exec(user, context, &scope_block)
      else
        raise ArgumentError, <<~ERROR
          Resource class #{resource_class.name} does not support scoping.

          Scoping requires the resource class to respond to `.all` (e.g., ActiveRecord models).

          To fix this:
            - If using ActiveRecord: Ensure your model inherits from ApplicationRecord or ActiveRecord::Base
            - If using a different ORM: Implement a `.all` class method that returns a collection
            - If scoping isn't needed: Remove the `scope :#{action}` declaration from #{self.class.name}

          Example for ActiveRecord:
            class #{resource_class.name} < ApplicationRecord
              # Your model code
            end
        ERROR
      end
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

    private

    def self.user_key_for(user)
      return "user:nil" if user.nil?
      
      if user.respond_to?(:id)
        "user:#{user.id}"
      elsif user.respond_to?(:to_key)
        "user:#{user.to_key.join('-')}"
      else
        "user:#{user.object_id}"
      end
    end
  end
end
