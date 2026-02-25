# frozen_string_literal: true

begin
  require_relative "../../lib/migration_version" unless defined?(MigrationVersion)
rescue LoadError
end

MIGRATION_VERSION_TEAMS = defined?(MigrationVersion) ? MigrationVersion::VERSION : "7.0"

class CreateTeams < ActiveRecord::Migration[MIGRATION_VERSION_TEAMS]
  def change
    create_table :teams do |t|
      t.string :name, null: false

      t.timestamps
    end
  end
end
