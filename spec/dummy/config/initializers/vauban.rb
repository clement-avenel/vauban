# frozen_string_literal: true

Vauban.configure do |config|
  config.current_user_method = :current_user
  config.cache_store = Rails.cache if defined?(Rails.cache)
  config.frontend_api_enabled = true
  config.frontend_cache_ttl = 5.minutes
end

# Policy discovery is handled automatically by Vauban::Railtie
# after Rails has fully initialized, so models are available
