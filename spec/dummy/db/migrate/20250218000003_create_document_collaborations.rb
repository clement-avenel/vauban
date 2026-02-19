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

      t.timestamps
    end

    add_index :document_collaborations, [:document_id, :user_id], unique: true
    
    # Create permissions join table
    create_table :document_collaboration_permissions do |t|
      t.references :document_collaboration, null: false, foreign_key: true
      t.string :permission, null: false

      t.timestamps
    end

    add_index :document_collaboration_permissions, 
              [:document_collaboration_id, :permission], 
              unique: true, 
              name: "index_doc_collab_perms_on_collab_and_permission"
  end
end
