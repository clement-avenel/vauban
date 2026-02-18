# frozen_string_literal: true

require "vauban/railtie"
require "vauban/rails/controller_helpers"
require "vauban/rails/view_helpers"
require "vauban/generators" if defined?(Rails)

module Vauban
  module Rails
    # Rails integration module
  end
end

# Auto-include helpers
if defined?(ActionController::Base)
  ActionController::Base.include Vauban::Rails::ControllerHelpers
end

if defined?(ActionView::Base)
  ActionView::Base.include Vauban::Rails::ViewHelpers
end
