# frozen_string_literal: true

class CreateDocumentCollaborations < ActiveRecord::Migration[8.1]
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
