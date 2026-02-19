# frozen_string_literal: true

module Vauban
  module Rails
    # Shared authorization helper methods used by both controllers and views
    module AuthorizationHelpers
      # Check if user can perform an action on a resource
      def can?(action, resource, context: {})
        current_user = send(Vauban.config.current_user_method)
        Vauban.can?(current_user, action, resource, context: context)
      end

      # Check if user cannot perform an action on a resource
      def cannot?(action, resource, context: {})
        !can?(action, resource, context: context)
      end
    end
  end
end
