# frozen_string_literal: true

module Vauban
  module Rails
    module ControllerHelpers
      extend ActiveSupport::Concern

      included do
        helper_method :can?, :cannot?
      end

      def authorize!(action, resource, context: {})
        current_user = send(Vauban.config.current_user_method)
        Vauban.authorize(current_user, action, resource, context: context)
      end

      def can?(action, resource, context: {})
        current_user = send(Vauban.config.current_user_method)
        Vauban.can?(current_user, action, resource, context: context)
      end

      def cannot?(action, resource, context: {})
        !can?(action, resource, context: context)
      end
    end
  end
end
