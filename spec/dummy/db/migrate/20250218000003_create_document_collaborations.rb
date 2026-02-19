# frozen_string_literal: true

# Load migration version helper if available
begin
  require_relative "../../lib/migration_version" unless defined?(MigrationVersion)
rescue LoadError
  # MigrationVersion not available, use default
end

# Use dynamic version if available, otherwise fall back to 7.0 (lowest supported)
MIGRATION_VERSION = defined?(MigrationVersion) ? MigrationVersion::VERSION : "7.0"

class CreateDocumentCollaborations < ActiveRecord::Migration[MIGRATION_VERSION]
  def change
    create_table :document_collaborations do |t|
      t.references :document, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :permissions  # Serialized array

      t.timestamps
    end

    add_index :document_collaborations, [:document_id, :user_id], unique: true
  end
end
