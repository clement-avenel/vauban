# frozen_string_literal: true

# Load migration version helper if available
begin
  require_relative "../../lib/migration_version" unless defined?(MigrationVersion)
rescue LoadError
  # MigrationVersion not available, use default
end

# Use dynamic version if available, otherwise fall back to 7.0 (lowest supported)
MIGRATION_VERSION = defined?(MigrationVersion) ? MigrationVersion::VERSION : "7.0"

class CreateDocuments < ActiveRecord::Migration[MIGRATION_VERSION]
  def change
    create_table :documents do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :title
      t.text :content
      t.boolean :public, default: false
      t.boolean :archived, default: false

      t.timestamps
    end
  end
end
