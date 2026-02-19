# frozen_string_literal: true

require "vauban/rails/authorization_helpers"

module Vauban
  module Rails
    module ControllerHelpers
      extend ActiveSupport::Concern

      included do
        include AuthorizationHelpers
        helper_method :can?, :cannot?
      end

      def authorize!(action, resource, context: {})
        current_user = send(Vauban.config.current_user_method)
        Vauban.authorize(current_user, action, resource, context: context)
      end
    end
  end
end
