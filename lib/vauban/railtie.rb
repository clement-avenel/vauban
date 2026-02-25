# frozen_string_literal: true

require "vauban/rails/helpers"

module Vauban
  class Railtie < ::Rails::Railtie
    initializer "vauban.configure", after: :load_config_initializers do
      Vauban.configure do |config|
        config.current_user_method ||= :current_user
        config.cache_store ||= ::Rails.cache if defined?(::Rails.cache)
      end
    end

    initializer "vauban.helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        include Vauban::Rails::ControllerHelpers
      end

      ActiveSupport.on_load(:action_view) do
        include Vauban::Rails::ViewHelpers
      end
    end

    initializer "vauban.discover_policies" do
      config.after_initialize do
        Vauban::Registry.discover_and_register
      end
    end

    generators do
      require "generators/vauban/install_generator"
      require "generators/vauban/policy_generator"
      require "generators/vauban/relationships_generator"
    end
  end
end
