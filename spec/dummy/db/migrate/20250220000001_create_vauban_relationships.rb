# frozen_string_literal: true

begin
  require_relative "../../lib/migration_version" unless defined?(MigrationVersion)
rescue LoadError
end

MIGRATION_VERSION_REL = defined?(MigrationVersion) ? MigrationVersion::VERSION : "7.0"

class CreateVaubanRelationships < ActiveRecord::Migration[MIGRATION_VERSION_REL]
  def change
    create_table :vauban_relationships do |t|
      t.string  :subject_type, null: false
      t.bigint  :subject_id,   null: false
      t.string  :relation,     null: false
      t.string  :object_type,  null: false
      t.bigint  :object_id,    null: false
      t.timestamps
    end

    add_index :vauban_relationships,
      [:subject_type, :subject_id, :relation, :object_type, :object_id],
      unique: true,
      name: "idx_vauban_rel_unique_tuple"

    add_index :vauban_relationships,
      [:object_type, :object_id, :relation],
      name: "idx_vauban_rel_object_relation"

    add_index :vauban_relationships,
      [:subject_type, :subject_id],
      name: "idx_vauban_rel_subject"

    add_index :vauban_relationships,
      [:relation],
      name: "idx_vauban_rel_relation"
  end
end
