# frozen_string_literal: true

require "vauban/version"
require "vauban/resource_identifier"
require "vauban/error_message_builder"
require "vauban/error_handler"
require "vauban/policy"
require "vauban/registry"
require "vauban/permission"
require "vauban/configuration"
require "vauban/cache_key_builder"
require "vauban/cache"
require "vauban/association_preloader"
require "vauban/batch_permission_checker"

# Rails integration (auto-loaded if Rails is available)
if defined?(Rails)
  require "vauban/rails"
  require "vauban/engine"
end

module Vauban
  class Error < StandardError; end

  class Unauthorized < Error
    attr_reader :user, :action, :resource, :available_permissions

    def initialize(user, action, resource, available_permissions: nil, context: {})
      @user = user
      @action = action
      @resource = resource
      @available_permissions = available_permissions
      @context = context

      message = build_message
      super(message)
    end

    private

    def build_message
      user_info = ResourceIdentifier.user_info_string(@user)
      resource_info = ResourceIdentifier.resource_info_string(@resource)
      permissions_info = permissions_info_string(@available_permissions)

      parts = [
        "Not authorized to perform '#{@action}' on #{resource_info}",
        ("User: #{user_info}" if user_info),
        ("Available permissions: #{permissions_info}" if permissions_info),
        debug_section
      ]

      ErrorMessageBuilder.build(*parts)
    end

    def permissions_info_string(permissions)
      return "none" if permissions.nil? || permissions.empty?
      permissions.map { |p| ":#{p}" }.join(", ")
    end

    def debug_section
      return nil if @context.empty?

      debug_items = [
        "Check your policy's :#{@action} permission rules",
        "Verify the user has the required relationships"
      ]
      debug_items << "Review context: #{@context.inspect}" unless @context.empty?

      ErrorMessageBuilder.section("To debug:", debug_items)
    end
  end

  class PolicyNotFound < Error
    attr_reader :resource_class, :expected_policy_name

    def initialize(resource_class, context: {})
      @resource_class = resource_class
      resource_name = resource_class_name(resource_class)
      @expected_policy_name = "#{resource_name}Policy"
      @context = context

      message = build_message(resource_name)
      super(message)
    end

    private

    def resource_class_name(resource_class)
      return "Unknown" unless resource_class
      return resource_class.name if resource_class.respond_to?(:name) && resource_class.name
      return resource_class.to_s if resource_class.respond_to?(:to_s)
      resource_class.class.name
    end

    def underscore_class_name(class_name)
      return class_name unless class_name
      # Use ActiveSupport's underscore if available, otherwise use a simple fallback
      if defined?(ActiveSupport::Inflector)
        ActiveSupport::Inflector.underscore(class_name)
      else
        # Simple fallback: convert CamelCase to snake_case
        class_name.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                  .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                  .downcase
      end
    end

    def build_message(resource_name)
      parts = [
        "No policy found for #{resource_name}",
        "Expected policy class: #{@expected_policy_name}",
        fix_section(resource_name),
        ("Context: #{@context.inspect}" unless @context.empty?)
      ]

      ErrorMessageBuilder.build(*parts)
    end

    def fix_section(resource_name)
      if resource_name != "Unknown"
        file_name = underscore_class_name(resource_name)
        fix_items = [
          "Create a policy file: app/policies/#{file_name}_policy.rb",
          "Define the policy class:"
        ]
        
        code_example = [
          "class #{@expected_policy_name} < Vauban::Policy",
          "  resource #{resource_name}",
          "",
          "  permission :view do",
          "    allow_if { |resource, user| # your authorization logic }",
          "  end",
          "end"
        ]
        
        ErrorMessageBuilder.build(
          ErrorMessageBuilder.section("To fix this:", fix_items),
          ErrorMessageBuilder.code_section("", code_example),
          "If using Packwerk, place it in: packs/*/app/policies/#{file_name}_policy.rb"
        )
      else
        fix_items = [
          "Create a policy class that inherits from Vauban::Policy",
          "Register it using Vauban::Registry.register"
        ]
        ErrorMessageBuilder.section("To fix this:", fix_items)
      end
    end
  end

  class ResourceNotFound < Error
    attr_reader :resource_class, :identifier

    def initialize(resource_class, identifier: nil, context: {})
      @resource_class = resource_class
      @identifier = identifier
      @context = context

      message = build_message
      super(message)
    end

    private

    def build_message
      fix_items = [
        "Ensure the resource exists before authorization",
        "Check that the identifier is correct",
        "Verify the resource class is correct"
      ]

      parts = [
        "Resource not found",
        ("Resource class: #{@resource_class.name}" if @resource_class),
        ("Identifier: #{@identifier.inspect}" if @identifier),
        ErrorMessageBuilder.section("To fix this:", fix_items),
        ("Context: #{@context.inspect}" unless @context.empty?)
      ]

      ErrorMessageBuilder.build(*parts)
    end
  end

  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    def config
      # Always ensure configuration is initialized
      self.configuration ||= Configuration.new
    end

    # Main authorization method
    def authorize(user, action, resource, context: {})
      policy_class = Registry.policy_for(resource.class)
      unless policy_class
        raise PolicyNotFound.new(resource.class, context: context)
      end

      # Use can? which is cached, but raise exception if not allowed
      allowed = can?(user, action, resource, context: context)
      unless allowed
        # Get available permissions for better error message
        available_permissions = policy_class.available_permissions if policy_class
        raise Unauthorized.new(user, action, resource, available_permissions: available_permissions, context: context)
      end

      true
    end

    # Check permission without raising
    def can?(user, action, resource, context: {})
      cache_key = Cache.key_for_permission(user, action, resource, context: context)

      Cache.fetch(cache_key) do
        policy_class = Registry.policy_for(resource.class)
        return false unless policy_class

        # Use memoized policy instance
        policy = policy_class.instance_for(user)
        policy.allowed?(action, resource, user, context: context)
      end
    rescue StandardError => e
      # Fail-safe: deny access on any error
      # Only log in development/test to avoid noise in production
      if development_or_test?
        ErrorHandler.handle_authorization_error(e, context: { action: action, resource: resource.class.name })
      end
      false
    end

    # Get all permissions for a resource
    def all_permissions(user, resource, context: {})
      cache_key = Cache.key_for_all_permissions(user, resource, context: context)

      Cache.fetch(cache_key) do
        policy_class = Registry.policy_for(resource.class)
        return {} unless policy_class

        # Use memoized policy instance
        policy = policy_class.instance_for(user)
        policy.all_permissions(user, resource, context: context)
      end
    rescue StandardError => e
      # Fail-safe: return empty permissions on error
      # Log in development/test to help debug issues
      ErrorHandler.handle_authorization_error(e, context: { resource: resource.class.name }) if development_or_test?
      {}
    end

    # Batch check permissions for multiple resources
    # Optimized to prevent N+1 queries by preloading associations and batch cache reads
    def batch_permissions(user, resources, context: {})
      BatchPermissionChecker.new(user, resources, context: context).call
    end

    # Get accessible records (scoping)
    def accessible_by(user, action, resource_class, context: {})
      policy_class = Registry.policy_for(resource_class)
      unless policy_class
        raise PolicyNotFound.new(resource_class, context: context)
      end

      # Use memoized policy instance
      policy = policy_class.instance_for(user)
      policy.scope(user, action, context: context)
    end

    # Clear all cached permissions
    def clear_cache!
      Cache.clear
    end

    # Clear cache for a specific resource (useful when resource is updated)
    def clear_cache_for_resource!(resource)
      Cache.clear_for_resource(resource)
    end

    # Clear cache for a specific user (useful when user permissions change)
    def clear_cache_for_user!(user)
      Cache.clear_for_user(user)
    end

    # Clear policy instance cache (useful for testing or when user permissions change)
    def clear_policy_instance_cache!
      Policy.clear_instance_cache!
    end

    private

    def development_or_test?
      defined?(::Rails) && ::Rails.respond_to?(:env) && (::Rails.env.development? || ::Rails.env.test?)
    end
  end
end
