# frozen_string_literal: true

# Helper to determine the correct migration version for the current Rails version
# This allows migrations to work across multiple Rails versions
# The version is determined at load time based on the installed ActiveRecord version
module MigrationVersion
  # Get the current ActiveRecord version as a string (e.g., "7.0" or "8.1")
  # This is used in migration class definitions
  VERSION = begin
    if defined?(ActiveRecord::VERSION)
      "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"
    else
      # Fallback to 7.0 if ActiveRecord isn't loaded yet
      "7.0"
    end
  end.freeze
end
