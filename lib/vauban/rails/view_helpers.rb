# frozen_string_literal: true

require "vauban/rails/authorization_helpers"

module Vauban
  module Rails
    module ViewHelpers
      include AuthorizationHelpers
    end
  end
end
