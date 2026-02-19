# frozen_string_literal: true

module Vauban
  # Utility module for identifying users and resources consistently across the codebase
  module ResourceIdentifier
    module_function

    # Generate a user identifier string for cache keys and logging
    # Returns: "user:nil", "user:123", "user:1-2-3", or "user:12345"
    def user_id_for(user)
      return "user:nil" if user.nil?

      if user.respond_to?(:id)
        "user:#{user.id}"
      elsif user.respond_to?(:to_key)
        "user:#{user.to_key.join('-')}"
      else
        "user:#{user.object_id}"
      end
    end

    # Generate a user key for policy instance caching
    # Alias for user_id_for for consistency
    def user_key_for(user)
      user_id_for(user)
    end

    # Generate a human-readable user info string for error messages and logging
    # Returns: "nil", "User#123", or "User"
    def user_info_string(user)
      return "nil" if user.nil?
      return "#{user.class.name}##{user.respond_to?(:id) ? user.id : 'unknown'}" if user.respond_to?(:id)
      user.class.name
    end

    # Generate a resource identifier string for cache keys
    # Returns: "nil", "Document:123", "class:Document", or "Document:12345"
    def resource_key_for(resource)
      return "nil" if resource.nil?

      if resource.respond_to?(:id)
        "#{resource.class.name}:#{resource.id}"
      elsif resource.is_a?(Class)
        "class:#{resource.name}"
      else
        "#{resource.class.name}:#{resource.object_id}"
      end
    end

    # Generate a human-readable resource info string for error messages and logging
    # Returns: "nil", "Document#123", or "Document"
    def resource_info_string(resource)
      return "nil" if resource.nil?
      return "#{resource.class.name}##{resource.id}" if resource.respond_to?(:id)
      resource.class.name
    end
  end
end
