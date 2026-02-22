# frozen_string_literal: true

Vauban.configure do |config|
  config.current_user_method = :current_user
  # config.cache_store = Rails.cache  # defaults to Rails.cache via Railtie
  # config.cache_ttl = 1.hour
  # config.policy_paths = ["app/policies/**/*_policy.rb"]
end
