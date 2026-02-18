# frozen_string_literal: true

module Vauban
  class Engine < ::Rails::Engine
    isolate_namespace Vauban

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot
    end
  end
end
