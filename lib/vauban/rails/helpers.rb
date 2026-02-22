# frozen_string_literal: true

module Vauban
  module Rails
    # Shared can?/cannot? used by both controllers and views.
    module AuthorizationHelpers
      def can?(action, resource, context: {})
        Vauban.can?(send(Vauban.config.current_user_method), action, resource, context: context)
      end

      def cannot?(action, resource, context: {})
        !can?(action, resource, context: context)
      end
    end

    # Included in controllers via Railtie. Adds authorize! and exposes can?/cannot? to views.
    module ControllerHelpers
      extend ActiveSupport::Concern
      include AuthorizationHelpers

      included do
        helper_method :can?, :cannot?
      end

      def authorize!(action, resource, context: {})
        Vauban.authorize(send(Vauban.config.current_user_method), action, resource, context: context)
      end
    end

    # Included in views via Railtie.
    module ViewHelpers
      include AuthorizationHelpers
    end
  end
end
