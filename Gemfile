# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in vauban.gemspec
gemspec

gem "rake", "~> 13.0"

group :development, :test do
  gem "rspec", "~> 3.0"
  gem "rspec-rails"
  gem "pry"
  gem "rubocop", "~> 1.0"
  gem "rubocop-rails-omakase", "~> 1.0"
  gem "simplecov", require: false
  # Dummy app dependencies (needed for integration tests)
  gem "sqlite3", ">= 2.1"
end
