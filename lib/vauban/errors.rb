# frozen_string_literal: true

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
      super(build_message)
    end

    private

    def build_message
      resource_info = ErrorHandler.display_name(@resource)
      user_info = ErrorHandler.display_name(@user)
      perms = @available_permissions&.map { |p| ":#{p}" }&.join(", ") || "none"

      msg = "Not authorized to perform '#{@action}' on #{resource_info}"
      msg += " (user: #{user_info}, available: #{perms})"
      msg += "\nContext: #{@context.inspect}" unless @context.empty?
      msg
    end
  end

  class PolicyNotFound < Error
    attr_reader :resource_class, :expected_policy_name

    def initialize(resource_class, context: {})
      @resource_class = resource_class
      name = resource_class&.respond_to?(:name) ? resource_class.name : resource_class.to_s
      @expected_policy_name = "#{name}Policy"

      msg = "No policy found for #{name}. Expected: #{@expected_policy_name}"
      msg += "\nContext: #{context.inspect}" unless context.empty?
      super(msg)
    end
  end

  class ResourceNotFound < Error
    attr_reader :resource_class, :identifier

    def initialize(resource_class, identifier: nil, context: {})
      @resource_class = resource_class
      @identifier = identifier

      msg = "Resource not found"
      msg += " (#{resource_class.name})" if resource_class&.respond_to?(:name)
      msg += " with identifier #{identifier.inspect}" if identifier
      msg += "\nContext: #{context.inspect}" unless context.empty?
      super(msg)
    end
  end
end
