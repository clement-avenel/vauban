# frozen_string_literal: true

require "vauban/version"
require "vauban/error_handler"
require "vauban/policy"
require "vauban/registry"
require "vauban/permission"
require "vauban/configuration"
require "vauban/cache"
require "vauban/errors"
require "vauban/authorization"

require "vauban/railtie" if defined?(Rails)

module Vauban
  extend ConfigurationMethods
  extend Authorization
end
