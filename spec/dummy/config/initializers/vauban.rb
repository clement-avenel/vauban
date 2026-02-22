# frozen_string_literal: true

Vauban.configure do |config|
  config.current_user_method = :current_user
  config.cache_store = Rails.cache if defined?(Rails.cache)
end
