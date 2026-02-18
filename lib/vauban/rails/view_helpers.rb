# frozen_string_literal: true

module Vauban
  module Rails
    module ViewHelpers
      def can?(action, resource, context: {})
        current_user = send(Vauban.config.current_user_method)
        Vauban.can?(current_user, action, resource, context: context)
      end

      def cannot?(action, resource, context: {})
        !can?(action, resource)
      end
    end
  end
end
