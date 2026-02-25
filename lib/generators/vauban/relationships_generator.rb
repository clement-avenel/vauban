# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Vauban
  module Generators
    class RelationshipsGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def create_migration
        migration_template(
          "create_vauban_relationships.rb.erb",
          "db/migrate/create_vauban_relationships.rb"
        )
      end

      private

      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end
    end
  end
end
