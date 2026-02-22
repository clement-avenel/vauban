# frozen_string_literal: true

module Vauban
  # Base error class for all Vauban errors.
  class Error < StandardError; end

  # Raised by {Vauban.authorize} when the user lacks permission.
  #
  # @attr_reader user [Object] the user who was denied
  # @attr_reader action [Symbol] the action that was denied
  # @attr_reader resource [Object] the resource that was accessed
  # @attr_reader available_permissions [Array<Symbol>] permissions defined on the policy
  class Unauthorized < Error
    attr_reader :user, :action, :resource, :available_permissions

    # @param user [Object]
    # @param action [Symbol]
    # @param resource [Object]
    # @param available_permissions [Array<Symbol>, nil]
    # @param context [Hash]
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

  # Raised when no policy is registered for a resource class.
  #
  # @attr_reader resource_class [Class] the class that has no policy
  # @attr_reader expected_policy_name [String] the conventional policy name
  class PolicyNotFound < Error
    attr_reader :resource_class, :expected_policy_name

    # @param resource_class [Class]
    # @param context [Hash]
    def initialize(resource_class, context: {})
      @resource_class = resource_class
      name = resource_class&.respond_to?(:name) ? resource_class.name : resource_class.to_s
      @expected_policy_name = "#{name}Policy"

      msg = "No policy found for #{name}. Expected: #{@expected_policy_name}"
      msg += "\nContext: #{context.inspect}" unless context.empty?
      super(msg)
    end
  end
end
